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
  suggestNextLoad,
  toBlocks,
} from "./progression.js";
export {
  CATEGORIES,
  LOAD_UNITS,
  MAX_VOLUME,
  VOLUME_KINDS,
  categorySchema,
  defaultLoadRange,
  defaultTargetRange,
  formatLoad,
  formatLoadDelta,
  formatVolume,
  formatVolumeRange,
  loadUnitSchema,
  snapToStep,
  volumeKindSchema,
  volumeZuGross,
} from "./belastung.js";
export type { Category, Group, LoadUnit, VolumeKind } from "./belastung.js";
export {
  befestigungsartSchema,
  herkunftPruefen,
  repEventsSchema,
  unsicherGrundSchema,
  volumeSourceSchema,
  type RepEvents,
  type VolumeSource,
} from "./herkunft.js";
export { DomainError, PlanNichtMoeglichError } from "./errors.js";
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
export { copyCatalogDefaults } from "./typ-vorlage.js";
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
  catalogTypeRequired,
  detachCatalogExercise,
  getStudioCatalog,
  listCatalogTypes,
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
  CatalogProduct,
  CatalogType,
  CatalogTypeExercise,
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
export { getEquipmentModelContext, getMachineContext } from "./machine-context.js";
export type { MachineContext } from "./machine-context.js";
export { getMachinePhotos } from "./machine-photos.js";
export type { MachinePhotos } from "./machine-photos.js";
export { getExerciseVideos } from "./exercise-videos.js";
export type { ExerciseVideos } from "./exercise-videos.js";
export type { DomainErrorCode } from "./errors.js";
export {
  completeSession,
  completeSessionInputSchema,
  deleteSession,
  deleteSessionInputSchema,
  problemReasonSchema,
  recordSet,
  recordSetInputSchema,
  reopenSession,
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
  Blockeinheiten,
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
export {
  acceptStaffInvite,
  createStaffInvite,
  getStaffInviteInfo,
  istEinladungsToken,
  listStaffInvites,
  revokeStaffInvite,
} from "./einladungen.js";
export type { StaffInvite, StaffInviteInfo } from "./einladungen.js";
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
export {
  CARDIO_WERTE,
  cardioListeSchema,
  cardioWerteSchema,
} from "./cardio.js";
export type { CardioWert, CardioWerte } from "./cardio.js";
export {
  BAUSTEINE,
  BEREICHE,
  ERFAHRUNG,
  FOKUS_BEREICHE,
  MINUTEN,
  PFLICHT_BAUSTEINE,
  PLAN_TYPEN,
} from "./trainingsplan-typen.js";
export type {
  Baustein,
  Bereich,
  Erfahrung,
  FokusBereich,
  Minuten,
  PlanFeld,
  PlanTyp,
} from "./trainingsplan-typen.js";
export { requireUserId } from "./auth.js";
export {
  deleteTrainingLimits,
  getTrainingLimits,
  getTrainingProfile,
  pruefeTrainingsLimits,
  pruefeTrainingsprofil,
  saveTrainingLimits,
  saveTrainingProfile,
} from "./trainingsprofil.js";
export type { LimitStufe, TrainingLimits, TrainingProfile } from "./trainingsprofil.js";
export { PLAN_REGEL_VERSION, FOKUS_MUSKELN, strukturFuerTage, zielAusTrainingGoal, zielprofil } from "./trainingsplan-regeln.js";
export type { Struktur, Ziel as PlanZiel, Zielprofil } from "./trainingsplan-regeln.js";
export { ZEIT, aufwaermenMinuten, cardioMinuten, pauseSekunden, uebungMinuten } from "./trainingsplan-zeit.js";
export { generierePlan } from "./trainingsplan-generator.js";
export type {
  GeneratorEingabe,
  GeneratorErgebnis,
  Kandidat,
  PlanEinheit,
  PlanPosition,
} from "./trainingsplan-generator.js";
export { ladeKandidaten } from "./trainingsplan-kandidaten.js";
export {
  acceptPlan,
  aktivePlaeneDerMitgliedschaften,
  erzeugePlanVorschlag,
  listPlaene,
  tauschePlanPosition,
} from "./trainingsplan.js";
export {
  ANFAENGER_EINHEITEN,
  alternativenJeBaustein,
  anfaengerphaseVorbei,
  gezaehlteEinheiten,
  ladeGezaehlteEinheiten,
  ladePlaeneFuerApp,
  NACHHOLEN_HOECHSTENS,
  nachzuholendeSessions,
  planFuerApp,
} from "./trainingsplan-bootstrap.js";
export type {
  GezaehlteEinheit,
  PlanAlternative,
  PlanFuerApp,
  SessionFuerNachholen,
  SessionFuerZaehler,
} from "./trainingsplan-bootstrap.js";
export type { PlanEingabe, PlanStatus, PlanTausch, TrainingPlan } from "./trainingsplan.js";
export { ablaufNachSatz, ablaufTauschen, einheitZaehlt, naechsteEinheitKey } from "./trainingsplan-ablauf.js";
export type { AblaufPosition, AblaufSatz, AblaufZustand, PositionStatus } from "./trainingsplan-ablauf.js";
export {
  PLANGEWICHT_ALGO_VERSION,
  berechnePlanGewicht,
  type PlanGewichtEingabe,
  type PlanGewichtErgebnis,
  type PlanGewichtGrund,
} from "./plangewicht.js";
export {
  STARTSCHAETZUNG_VERSION,
  WIEDEREINSTIEG_VERSION,
  schaetzeStartgewicht,
  startgewichtAusHistorie,
  uebertragungsFaktor,
  wiedereinstieg,
  type Geraetegrenzen,
} from "./plangewicht-start.js";
export {
  aktualisierePlanGewichte,
  initialisierePlanGewichte,
  ladeZielgewichte,
  ohneAbbruch,
  uebernehmePlanGewichte,
  zielSchluessel,
  type Melde,
  type PositionsZiel,
} from "./plangewichte.js";
