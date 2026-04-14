import { Controller, Get, Param } from '@nestjs/common';
import { CmsService } from './cms.service';

@Controller('cms')
export class CmsController {
  constructor(private readonly cms: CmsService) {}

  @Get('pages')
  listPages() {
    return this.cms.listPublished();
  }

  @Get('pages/:slug')
  getPage(@Param('slug') slug: string) {
    return this.cms.getBySlugOrThrow(slug);
  }
}
