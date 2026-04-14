import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { AddSupportMessageDto } from './dto/add-support-message.dto';
import { CreateSupportTicketDto } from './dto/create-support-ticket.dto';
import { SupportService } from './support.service';

@Controller('order/support')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  private uid(req: Request): string {
    const u = req.supabaseJwt?.sub;
    if (!u) throw new UnauthorizedException();
    return u;
  }

  @Post('tickets')
  create(@Body() dto: CreateSupportTicketDto, @Req() req: Request) {
    return this.support.createTicket(this.uid(req), dto.subject, dto.body);
  }

  @Get('tickets')
  list(@Req() req: Request) {
    return this.support.listMyTickets(this.uid(req));
  }

  @Get('tickets/:ticketId')
  one(@Param('ticketId') ticketId: string, @Req() req: Request) {
    return this.support.getTicket(this.uid(req), ticketId);
  }

  @Post('tickets/:ticketId/messages')
  addMessage(
    @Param('ticketId') ticketId: string,
    @Body() dto: AddSupportMessageDto,
    @Req() req: Request,
  ) {
    return this.support.addCustomerMessage(this.uid(req), ticketId, dto.body);
  }
}
