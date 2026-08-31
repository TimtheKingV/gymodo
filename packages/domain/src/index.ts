export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
export { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";
export {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./progression.js";
export { DomainError } from "./errors.js";
export { getTagContext } from "./tag-context.js";
export type { TagContext } from "./tag-context.js";
export type { DomainErrorCode } from "./errors.js";
export {
  completeSession,
  completeSessionInputSchema,
  problemReasonSchema,
  recordSet,
  recordSetInputSchema,
} from "./workout.js";
export type {
  CompletedSession,
  ProblemReason,
  RecordSetInput,
  RecordedSet,
} from "./workout.js";
export type {
  BlockInput,
  ProgressionInput,
  ProgressionInputsRecord,
  ProgressionReasonCode,
  ProgressionSuggestion,
  WorkoutSetInput,
} from "./progression.js";
