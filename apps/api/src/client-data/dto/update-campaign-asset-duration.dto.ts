import { IsInt, Min } from 'class-validator';

export class UpdateCampaignAssetDurationDto {
  @IsInt()
  @Min(1)
  durationSeconds!: number;
}
