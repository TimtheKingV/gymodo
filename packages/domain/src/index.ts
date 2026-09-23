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
  toBlocks,
} from "./progression.js";
export { DomainError } from "./errors.js";
export { istAuthAusfall } from "./auth.js";
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
  exercisePatchSchema,
  getStudioCatalog,
  listStudioExercises,
  reactivateMachine,
  reorderModelExercises,
  revokeTag,
  settingDefinitionInputSchema,
  updateEquipmentModel,
  updateExercise,
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
export {
  anzeigenameSchema,
  pruefeAnzeigename,
  profilSchema,
  pruefeProfil,
  updateProfile,
  zuProfil,
  SEX,
  AGE_BANDS,
  TRAINING_GOALS,
} from "./profil.js";
export type { Profil, ProfilEingabe } from "./profil.js";
export { getProgress, progressOptionsSchema } from "./progress.js";
export type { ExerciseProgress, Progress, ProgressOptions, ProgressPoint } from "./progress.js";
export {
  messwertSchema,
  pruefeMesswert,
  zielErreicht,
  getMeasurements,
  putMeasurement,
  deleteMeasurement,
} from "./measurements.js";
export type { Measurements, Messpunkt, RecordedMeasurement } from "./measurements.js";
export {
  GOAL_KINDS,
  zielSchema,
  pruefeZiel,
  setGoal,
  dropGoal,
  aktiveZiele,
  markiereErreicht,
} from "./goals.js";
export type { AktiveZiele, GoalKind, Ziel } from "./goals.js";
export { getSessions, serienstand, zaehleDieseWoche } from "./sessions.js";
export type {
  Serienstand,
  SessionBlock,
  SessionSummary,
  Sessions,
  SessionsOptions,
  SessionsSummary,
} from "./sessions.js";
export type { Bootstrap } from "./bootstrap.js";
export { getTagContext } from "./tag-context.js";
export type { TagContext } from "./tag-context.js";
export { getMachineContext } from "./machine-context.js";
export type { MachineContext } from "./machine-context.js";
export { getMachinePhotos } from "./machine-photos.js";
export type { MachinePhotos } from "./machine-photos.js";
export type { DomainErrorCode } from "./errors.js";
export {
  completeSession,
  completeSessionInputSchema,
  deleteSession,
  deleteSessionInputSchema,
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
export {
  recordCalibration,
  recordCalibrationInputSchema,
  pruefeEinstellwerte,
} from "./calibration.js";
export type {
  RecordCalibrationInput,
  RecordedCalibration,
  EinstellDefinition,
} from "./calibration.js";
export type {
  BlockInput,
  ProgressionInput,
  ProgressionInputsRecord,
  ProgressionReasonCode,
  ProgressionSuggestion,
  SatzZeile,
  WorkoutSetInput,
} from "./progression.js";
export {
  ABSCHLUSS_ZEITFENSTER_MS,
  vorschlaegeFuerAbschluss,
  gespeicherteVorschlaege,
  ausGespeichertenZeilen,
  blockPaare,
  zuVorschlag,
} from "./abschluss.js";
export type {
  Blockvorschlag,
  GespeicherteVorschlagZeile,
} from "./abschluss.js";
export {
  joinStudioByCode,
  joinStudioByTag,
  leaveStudio,
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
  abmeldenBis,
  bookCourseSession,
  cancelCourseBooking,
  cancelCourseSession,
  createCourseSessions,
  createCourseTemplate,
  getCourseTemplate,
  listCourseParticipants,
  listCourseTemplates,
  listCourseWeek,
  updateCourseSession,
  updateCourseTemplate,
} from "./courses.js";
export type {
  BookOutcome,
  CancelOutcome,
  CourseParticipant,
  CourseSessionInput,
  CourseTemplate,
  CourseTemplateInput,
  CourseWeek,
  CourseWeekSession,
} from "./courses.js";
export {
  MAX_SERIENTERMINE,
  ortszeitTeile,
  ortszeitZuInstant,
  serienTermine,
  zonenVersatzMs,
} from "./serie.js";
export type { Ortszeit } from "./serie.js";
