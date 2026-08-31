export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
export { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";
export {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./progression.js";
export { DomainError } from "./errors.js";
export { getBootstrap } from "./bootstrap.js";
export { getProgress, progressOptionsSchema } from "./progress.js";
export type { ExerciseProgress, Progress, ProgressOptions, ProgressPoint } from "./progress.js";
export { getSessions } from "./sessions.js";
export type { SessionBlock, SessionSummary, Sessions } from "./sessions.js";
export type { Bootstrap } from "./bootstrap.js";
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
