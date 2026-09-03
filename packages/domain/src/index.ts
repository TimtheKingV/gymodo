export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
export { createTagToken, hashTagToken } from "./tags.js";
export {
  TAG_TOKEN_LENGTH,
  TAG_TOKEN_PATTERN,
  isValidTagToken,
  parseTagScan,
} from "./tag-scan.js";
export { naechsteGeraeteNummer } from "./nummern.js";
export {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./progression.js";
export { DomainError } from "./errors.js";
export {
  MAX_PHOTO_BYTES,
  MAX_VIDEO_BYTES,
  MAX_VIDEO_SECONDS,
  MEDIA_URL_TTL_SECONDS,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  readVideoDurationSeconds,
  sniffMediaType,
  stripImageMetadata,
} from "./media.js";
export type { MediaKind } from "./media.js";
export {
  confirmInstructionVideo,
  prepareInstructionVideoUpload,
  signMediaUrl,
  signMediaUrls,
  uploadEquipmentPhoto,
} from "./media-store.js";
export { getStudioSettings, requireStudioStaff, updateStudioSettings } from "./studio.js";
export type { StudioSettings, StudioSettingsInput } from "./studio.js";
export {
  assignTag,
  attachExerciseToModel,
  createEquipmentModel,
  createExercise,
  createMachine,
  createSettingDefinition,
  deactivateMachine,
  deleteSettingDefinition,
  detachExercise,
  equipmentModelInputSchema,
  equipmentModelPatchSchema,
  exerciseInputSchema,
  getStudioCatalog,
  listStudioExercises,
  reactivateMachine,
  reorderModelExercises,
  revokeTag,
  settingDefinitionInputSchema,
  updateEquipmentModel,
} from "./catalog.js";
export type {
  CatalogExercise,
  CatalogMachine,
  CatalogModel,
  CatalogSettingDefinition,
  CatalogShipment,
  CatalogTag,
  EquipmentModelInput,
  StudioCatalog,
  StudioExercise,
} from "./catalog.js";
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
export {
  joinStudioByCode,
  listStudioMembers,
  regenerateStudioJoinCode,
  removeMembership,
  setMembershipRole,
  setStudioJoinCodeActive,
} from "./people.js";
export type { StudioMember } from "./people.js";
export { getStudioOverview } from "./overview.js";
export type {
  OverviewMachine,
  OverviewProblem,
  StudioOverview,
} from "./overview.js";
export {
  createCourseTemplate,
  getCourseTemplate,
  listCourseTemplates,
  updateCourseTemplate,
} from "./courses.js";
export type { CourseTemplate, CourseTemplateInput } from "./courses.js";
