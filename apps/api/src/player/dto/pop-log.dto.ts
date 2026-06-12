import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

enum PopStatus {
  VERIFIED = 'VERIFIED',
  FAILED = 'FAILED',
}

class PopLogEntry {
  @IsOptional()
  @IsString()
  assetName?: string;

  @IsOptional()
  @IsString()
  content?: string;

  @IsOptional()
  @IsString()
  playlistName?: string;

  @IsOptional()
  @IsString()
  campaignName?: string;

  @IsEnum(PopStatus)
  status!: PopStatus;

  @IsOptional()
  @IsDateString()
  startTime?: string;

  @IsOptional()
  @IsDateString()
  endTime?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationSeconds?: number;

  /** @deprecated Use startTime */
  @IsOptional()
  @IsDateString()
  timestamp?: string;
}

export class SubmitPopLogsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PopLogEntry)
  logs!: PopLogEntry[];
}

export type PopLogInput = PopLogEntry;
