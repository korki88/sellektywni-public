import { Injectable, Logger } from '@nestjs/common';
import { Prisma, ProfileRank } from '@prisma/client';
import OpenAI from 'openai';
import { AuditService } from '../audit/audit.service';
import { FirebasePushService } from '../notifications/firebase-push.service';
import { PrismaService } from '../prisma/prisma.service';
import { SocialMediaService } from '../social-media-integrator/social-media-integrator.service';

type HypeMakerInput = {
  proposalId: string;
  productId: string;
  productName: string;
  discountPercent: Prisma.Decimal;
  suggestedPrice: Prisma.Decimal;
  riskScore: number;
};

type HypeMakerCopy = {
  pushShort: string;
  socialPost: string;
  googleAdsHeadline: string;
};

type HypeMakerActor = {
  userId: string;
  userEmail: string;
};

@Injectable()
export class HypeMakerService {
  private readonly logger = new Logger(HypeMakerService.name);
  private readonly systemUserId = 'HYPE_MAKER_AI';
  private readonly systemEmail = 'HYPE_MAKER_AI';

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly firebasePush: FirebasePushService,
    private readonly social: SocialMediaService,
  ) {}

  private openAiClient(): OpenAI | null {
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) return null;
    return new OpenAI({ apiKey });
  }

  private fallbackCopy(input: HypeMakerInput): HypeMakerCopy {
    const discount = input.discountPercent.toString();
    const suggestedPrice = input.suggestedPrice.toString();
    return {
      pushShort:
        `${input.productName} właśnie trafił do oferty specjalnej (-${discount}%). ` +
        `Nowa cena ${suggestedPrice} zł — sprawdź zanim zniknie.`,
      socialPost:
        `Vintage luxury alert ✨ ${input.productName} teraz taniej o ${discount}%.\n` +
        `Nowa cena: ${suggestedPrice} zł. Limitowana dostępność.\n` +
        `#sellektywni #vintage #luxury #fashion #limiteddrop`,
      googleAdsHeadline: `${input.productName} -${discount}% | Styl vintage luxury`,
    };
  }

  private parseCopy(raw: string): HypeMakerCopy | null {
    const normalized = raw
      .replace(/```json/gi, '')
      .replace(/```/g, '')
      .trim();
    try {
      const parsed = JSON.parse(normalized) as Partial<HypeMakerCopy>;
      const pushShort = parsed.pushShort?.toString().trim() ?? '';
      const socialPost = parsed.socialPost?.toString().trim() ?? '';
      const googleAdsHeadline =
        parsed.googleAdsHeadline?.toString().trim() ?? '';
      if (!pushShort || !socialPost || !googleAdsHeadline) return null;
      return { pushShort, socialPost, googleAdsHeadline };
    } catch {
      return null;
    }
  }

  private async generateCopyWithAi(
    input: HypeMakerInput,
    segment: string,
  ): Promise<HypeMakerCopy | null> {
    const client = this.openAiClient();
    if (!client) return null;
    const model = process.env.HYPE_MAKER_OPENAI_MODEL?.trim() || 'gpt-4o';
    const response = await client.chat.completions.create({
      model,
      temperature: 0.7,
      messages: [
        {
          role: 'system',
          content:
            'Jesteś agentem marketingowym Hype Maker dla e-commerce premium. Odpowiadasz wyłącznie JSON-em.',
        },
        {
          role: 'user',
          content:
            'Wygeneruj trzy treści po polsku i zwróć JSON: ' +
            '{"pushShort":string,"socialPost":string,"googleAdsHeadline":string}. ' +
            'Wymagania: push emocjonalny i krótki; social post dla Instagram/Facebook ze stylem vintage/luxury i hashtagami; ' +
            'nagłówek Google Ads zorientowany na konwersję. ' +
            `Segment: ${segment}. Dane produktu: ${JSON.stringify({
              productName: input.productName,
              discountPercent: input.discountPercent.toString(),
              suggestedPrice: input.suggestedPrice.toString(),
              riskScore: input.riskScore,
            })}.`,
        },
      ],
    });
    const raw = response.choices[0]?.message?.content?.trim();
    if (!raw) return null;
    return this.parseCopy(raw);
  }

  private rankWeight(rank: ProfileRank): number {
    switch (rank) {
      case ProfileRank.VINTAGE:
        return 4;
      case ProfileRank.GOLD:
        return 3;
      case ProfileRank.SILVER:
        return 2;
      default:
        return 1;
    }
  }

  private actor(): HypeMakerActor {
    return {
      userId: this.systemUserId,
      userEmail: this.systemEmail,
    };
  }

  private async sendSegmentPush(
    input: HypeMakerInput,
    segment: string,
    copy: HypeMakerCopy,
  ): Promise<void> {
    await this.firebasePush.sendLoyaltySegmentNotification({
      segment,
      title: 'Nowa oferta premium',
      body: copy.pushShort,
      proposalId: input.proposalId,
      productName: input.productName,
    });
    await this.audit.logAction({
      userId: this.systemUserId,
      userEmail: this.systemEmail,
      action: 'HYPE_MAKER_PUSH_SENT',
      resourceType: 'AI_PROPOSAL',
      resourceId: input.proposalId,
      newValue: {
        segment,
        productId: input.productId,
        productName: input.productName,
        pushShort: copy.pushShort,
      },
    });
  }

  private async distributeSocial(
    input: HypeMakerInput,
    segment: string,
    copy: HypeMakerCopy,
  ) {
    const actor = this.actor();
    const target = `LOYALTY_${segment}`;
    return Promise.all([
      this.social.postToInstagram(
        {
          target,
          content: copy.socialPost,
        },
        actor,
      ),
      this.social.postToFacebook(
        {
          target,
          content: copy.socialPost,
        },
        actor,
      ),
      this.social.triggerGoogleAdsUpdate(
        {
          target,
          content: copy.googleAdsHeadline,
        },
        actor,
      ),
    ]).then(([instagram, facebook, googleAds]) => ({
      proposalId: input.proposalId,
      segment,
      copy,
      distribution: {
        instagram,
        facebook,
        googleAds,
      },
    }));
  }

  private async resolveSegmentForProduct(productId: string): Promise<string> {
    const watchers = await this.prisma.wishlistItem.findMany({
      where: { productId },
      select: { userId: true },
      distinct: ['userId'],
      take: 1000,
    });
    if (watchers.length === 0) return 'SILVER';
    const profiles = await this.prisma.profile.findMany({
      where: {
        userId: { in: watchers.map((w) => w.userId) },
      },
      select: { rank: true },
    });
    if (profiles.length === 0) return 'SILVER';

    let best: ProfileRank = ProfileRank.BRONZE;
    let bestWeight = 0;
    for (const profile of profiles) {
      const w = this.rankWeight(profile.rank);
      if (w > bestWeight) {
        best = profile.rank;
        bestWeight = w;
      }
    }
    return best.toString();
  }

  async runForApprovedProposal(input: HypeMakerInput): Promise<void> {
    const segment = await this.resolveSegmentForProduct(input.productId);
    const copy =
      (await this.generateCopyWithAi(input, segment).catch((error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.warn(`Hype Maker AI copy generation failed: ${message}`);
        return null;
      })) ?? this.fallbackCopy(input);

    await this.sendSegmentPush(input, segment, copy);
    const campaign = await this.distributeSocial(input, segment, copy);

    await this.audit.logAction({
      userId: this.systemUserId,
      userEmail: this.systemEmail,
      action: 'HYPE_MAKER_CAMPAIGN_ORCHESTRATED',
      resourceType: 'AI_PROPOSAL',
      resourceId: input.proposalId,
      newValue: {
        ...campaign,
      },
    });
  }
}
