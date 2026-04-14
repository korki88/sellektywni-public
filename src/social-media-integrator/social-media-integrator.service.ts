import { Injectable, Logger } from '@nestjs/common';
import {
  MarketingCampaignStatus,
  SocialPlatform,
  SocialConfigStatus,
} from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type SocialAuditActor = {
  userId: string;
  userEmail: string;
  ipAddress?: string | null;
};

type CampaignPayload = {
  target: string;
  content: string;
};

type SocialMockResult = {
  ok: true;
  mock: true;
  campaignId: string;
  externalId: string | null;
};

@Injectable()
export class SocialMediaService {
  private readonly logger = new Logger(SocialMediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
  ) {}

  private configEnvKeys(platform: SocialPlatform): {
    accessTokenKey: string;
    refreshTokenKey: string;
  } {
    switch (platform) {
      case SocialPlatform.INSTAGRAM:
        return {
          accessTokenKey: 'INSTAGRAM_ACCESS_TOKEN',
          refreshTokenKey: 'INSTAGRAM_REFRESH_TOKEN',
        };
      case SocialPlatform.FACEBOOK:
        return {
          accessTokenKey: 'FACEBOOK_ACCESS_TOKEN',
          refreshTokenKey: 'FACEBOOK_REFRESH_TOKEN',
        };
      case SocialPlatform.GOOGLE_ADS:
        return {
          accessTokenKey: 'GOOGLE_ADS_ACCESS_TOKEN',
          refreshTokenKey: 'GOOGLE_ADS_REFRESH_TOKEN',
        };
    }
  }

  private configFromEnv(platform: SocialPlatform): {
    accessToken: string;
    refreshToken: string | null;
    status: SocialConfigStatus;
  } {
    const keys = this.configEnvKeys(platform);
    const accessToken =
      this.config.get<string>(keys.accessTokenKey)?.trim() || '';
    const refreshToken =
      this.config.get<string>(keys.refreshTokenKey)?.trim() || null;
    return {
      accessToken,
      refreshToken,
      status: accessToken
        ? SocialConfigStatus.ACTIVE
        : SocialConfigStatus.INACTIVE,
    };
  }

  private async savePlatformConfig(platform: SocialPlatform): Promise<void> {
    const cfg = this.configFromEnv(platform);
    await this.prisma.socialConfig.upsert({
      where: { platform },
      create: {
        platform,
        accessToken: cfg.accessToken,
        refreshToken: cfg.refreshToken,
        status: cfg.status,
      },
      update: {
        accessToken: cfg.accessToken,
        refreshToken: cfg.refreshToken,
        status: cfg.status,
      },
    });
  }

  private async createMockCampaign(
    platform: SocialPlatform,
    payload: CampaignPayload,
  ) {
    const externalId = `mock-${platform.toLowerCase()}-${Date.now()}`;
    return this.prisma.marketingCampaign.create({
      data: {
        target: payload.target,
        content: payload.content,
        platform,
        status: MarketingCampaignStatus.MOCK_SENT,
        externalId,
      },
    });
  }

  private async logMockAction(
    actor: SocialAuditActor,
    platform: SocialPlatform,
    action: string,
    campaign: { id: string; externalId: string | null },
    payload: CampaignPayload,
  ): Promise<void> {
    this.logger.log(
      `[MOCK][${platform}] target="${payload.target}" content="${payload.content}" externalId="${campaign.externalId ?? 'n/a'}"`,
    );
    await this.audit.logAction({
      userId: actor.userId,
      userEmail: actor.userEmail,
      action,
      resourceType: 'MARKETING_CAMPAIGN',
      resourceId: campaign.id,
      newValue: {
        platform,
        target: payload.target,
        content: payload.content,
        externalId: campaign.externalId,
        mode: 'MOCK',
      },
      ipAddress: actor.ipAddress ?? null,
    });
  }

  private actionForPlatform(platform: SocialPlatform): string {
    switch (platform) {
      case SocialPlatform.INSTAGRAM:
        return 'SOCIAL_POST_INSTAGRAM_MOCK';
      case SocialPlatform.FACEBOOK:
        return 'SOCIAL_POST_FACEBOOK_MOCK';
      case SocialPlatform.GOOGLE_ADS:
        return 'SOCIAL_TRIGGER_GOOGLE_ADS_MOCK';
    }
  }

  private async publishMock(
    platform: SocialPlatform,
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<SocialMockResult> {
    await this.savePlatformConfig(platform);
    const campaign = await this.createMockCampaign(platform, payload);
    await this.logMockAction(
      actor,
      platform,
      this.actionForPlatform(platform),
      campaign,
      payload,
    );
    return {
      ok: true,
      mock: true,
      campaignId: campaign.id,
      externalId: campaign.externalId,
    };
  }

  async postToInstagram(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<SocialMockResult> {
    return this.publishMock(SocialPlatform.INSTAGRAM, payload, actor);
  }

  async postToFacebook(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<SocialMockResult> {
    return this.publishMock(SocialPlatform.FACEBOOK, payload, actor);
  }

  async triggerGoogleAdsUpdate(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<SocialMockResult> {
    return this.publishMock(SocialPlatform.GOOGLE_ADS, payload, actor);
  }
}
