export type Role = "guardian" | "adult" | "child";
export type OccurrenceStatus =
  | "scheduled"
  | "pending_review"
  | "completed"
  | "approved"
  | "needs_redo"
  | "cancelled";
export interface Actor {
  readonly uid: string;
  readonly emailVerified: boolean;
  readonly provider: string;
  readonly scopedChild: boolean;
}
export interface Membership {
  readonly role: Role;
  readonly status: "active" | "revoked";
  readonly canAssign: boolean;
}
export interface OccurrenceCommand {
  readonly householdId: string;
  readonly occurrenceId: string;
  readonly commandId: string;
  readonly baseVersion: number;
  readonly action: "complete" | "undo" | "help" | "approve" | "redo";
}
export type ConflictReason =
  | "already_done"
  | "reassigned"
  | "membership_revoked"
  | "occurrence_cancelled"
  | "version_conflict";
export type CommandResult =
  | {
      readonly accepted: true;
      readonly version: number;
      readonly status: OccurrenceStatus;
    }
  | {
      readonly accepted: false;
      readonly reason: ConflictReason;
      readonly version: number;
    };
