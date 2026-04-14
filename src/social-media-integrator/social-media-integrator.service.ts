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

@Injectable()
export class SocialMediaService {
  private readonly logger = new Logger(SocialMediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
  ) {}

  private configFromEnv(platform: SocialPlatform): {
    accessToken: string;
    refreshToken: string | null;
    status: SocialConfigStatus;
  } {
    switch (platform) {
      case SocialPlatform.INSTAGRAM: {
        const accessToken =
          this.config.get<string>('INSTAGRAM_ACCESS_TOKEN')?.trim() || '';
        const refreshToken =
          this.config.get<string>('INSTAGRAM_REFRESH_TOKEN')?.trim() || null;
        return {
          accessToken,
          refreshToken,
          status: accessToken
            ? SocialConfigStatus.ACTIVE
            : SocialConfigStatus.INACTIVE,
        };
      }
      case SocialPlatform.FACEBOOK: {
        const accessToken =
          this.config.get<string>('FACEBOOK_ACCESS_TOKEN')?.trim() || '';
        const refreshToken =
          this.config.get<string>('FACEBOOK_REFRESH_TOKEN')?.trim() || null;
        return {
          accessToken,
          refreshToken,
          status: accessToken
            ? SocialConfigStatus.ACTIVE
            : SocialConfigStatus.INACTIVE,
        };
      }
      case SocialPlatform.GOOGLE_ADS: {
        const accessToken =
          this.config.get<string>('GOOGLE_ADS_ACCESS_TOKEN')?.trim() || '';
        const refreshToken =
          this.config.get<string>('GOOGLE_ADS_REFRESH_TOKEN')?.trim() || null;
        return {
          accessToken,
          refreshToken,
          status: accessToken
            ? SocialConfigStatus.ACTIVE
            : SocialConfigStatus.INACTIVE,
        };
      }
    }
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

  async postToInstagram(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<{
    ok: true;
    mock: true;
    campaignId: string;
    externalId: string | null;
  }> {
    await this.savePlatformConfig(SocialPlatform.INSTAGRAM);
    const campaign = await this.createMockCampaign(
      SocialPlatform.INSTAGRAM,
      payload,
    );
    await this.logMockAction(
      actor,
      SocialPlatform.INSTAGRAM,
      'SOCIAL_POST_INSTAGRAM_MOCK',
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

  async postToFacebook(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<{
    ok: true;
    mock: true;
    campaignId: string;
    externalId: string | null;
  }> {
    await this.savePlatformConfig(SocialPlatform.FACEBOOK);
    const campaign = await this.createMockCampaign(
      SocialPlatform.FACEBOOK,
      payload,
    );
    await this.logMockAction(
      actor,
      SocialPlatform.FACEBOOK,
      'SOCIAL_POST_FACEBOOK_MOCK',
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

  async triggerGoogleAdsUpdate(
    payload: CampaignPayload,
    actor: SocialAuditActor,
  ): Promise<{
    ok: true;
    mock: true;
    campaignId: string;
    externalId: string | null;
  }> {
    await this.savePlatformConfig(SocialPlatform.GOOGLE_ADS);
    const campaign = await this.createMockCampaign(
      SocialPlatform.GOOGLE_ADS,
      payload,
    );
    await this.logMockAction(
      actor,
      SocialPlatform.GOOGLE_ADS,
      'SOCIAL_TRIGGER_GOOGLE_ADS_MOCK',
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
}
