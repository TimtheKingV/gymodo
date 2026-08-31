export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
export { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";
export {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./progression.js";
export type {
  BlockInput,
  ProgressionInput,
  ProgressionInputsRecord,
  ProgressionReasonCode,
  ProgressionSuggestion,
  WorkoutSetInput,
} from "./progression.js";
