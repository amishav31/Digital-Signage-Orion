import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class AddCampaignAssetDto {
  @IsString()
  assetId!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationSeconds?: number;
}
