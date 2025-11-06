import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getRoot(): string {
    return 'Reserve API v0.1.0';
  }

  getPing(): object {
    return {
      status: 'ok',
      message: 'pong',
      timestamp: new Date().toISOString(),
    };
  }

  getHealth(): object {
    return {
      status: 'healthy',
      service: 'reserve-api',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  }
}
