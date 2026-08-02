class BlackoutPeriod < ApplicationRecord
  DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/
  OVERLAP_MESSAGE =
    "That period overlaps an existing blackout.".freeze
  RESERVATION_CONFLICT_MESSAGE =
    "Cancel the confirmed reservations in this period before adding the blackout.".freeze

  attr_accessor :scope_value,
    :starts_on,
    :ends_on,
    :local_starts_at,
    :local_ends_at

  belongs_to :workspace
  belongs_to :shared_resource,
    optional: true
  belongs_to :created_by,
    class_name: "User"

  has_one :schedule_block,
    dependent: :destroy,
    inverse_of: :blackout_period

  normalizes :reason,
    with: ->(reason) { reason.strip.squish }

  validates :reason,
    presence: true,
    length: {
      maximum: 150
    }
  validates :starts_at,
    :ends_at,
    :time_zone,
    presence: true
  validates :time_zone,
    length: {
      maximum: 100
    }

  before_validation :capture_time_zone,
    on: :create

  validate :ends_after_start
  validate :ends_in_the_future,
    on: :create
  validate :resource_belongs_to_workspace
  validate :creator_can_manage_scope
  validate :time_zone_identifier_is_valid
  validate :all_day_boundaries_are_local_midnights
  validate :does_not_overlap_existing_blackout,
    on: :create
  validate :does_not_overlap_confirmed_reservation,
    on: :create

  after_create :create_schedule_block
  after_update :sync_schedule_block,
    if: :schedule_block_changed?

  scope :chronological, -> {
    order(:starts_at, :id)
  }
  scope :current_and_future, -> {
    where("ends_at > ?", Time.current)
  }
  scope :past, -> {
    where("ends_at <= ?", Time.current)
  }
  scope :applying_to, ->(shared_resource) {
    where(
      "shared_resource_id IS NULL OR shared_resource_id = ?",
      shared_resource.id
    )
  }

  def workspace_wide?
    shared_resource_id.nil?
  end

  def scope_label
    workspace_wide? ?
      "Entire workspace" :
      shared_resource.name
  end

  def active_now?
    starts_at <= Time.current &&
      ends_at > Time.current
  end

  def assign_local_schedule(
    starts_on:,
    ends_on:,
    local_starts_at:,
    local_ends_at:
  )
    self.starts_on = starts_on.to_s
    self.ends_on = ends_on.to_s
    self.local_starts_at = local_starts_at.to_s
    self.local_ends_at = local_ends_at.to_s

    if all_day?
      assign_all_day_schedule
    else
      assign_timed_schedule
    end

    errors.empty?
  end

  private

  def capture_time_zone
    self.time_zone = workspace.time_zone if workspace
  end

  def assign_all_day_schedule
    start_date = parse_date(starts_on, :starts_on)
    end_date = parse_date(ends_on, :ends_on)
    return unless start_date && end_date

    if end_date < start_date
      errors.add(
        :ends_on,
        "must be on or after the start date"
      )
      return
    end

    self.starts_at = local_midnight(
      start_date,
      :starts_on
    )
    self.ends_at = local_midnight(
      end_date.next_day,
      :ends_on
    )
  end

  def assign_timed_schedule
    self.starts_at = parse_local_datetime(
      local_starts_at,
      :local_starts_at
    )
    self.ends_at = parse_local_datetime(
      local_ends_at,
      :local_ends_at
    )
  end

  def parse_date(value, attribute)
    unless DATE_PATTERN.match?(value)
      errors.add(
        attribute,
        "must use a valid date"
      )
      return
    end

    Date.iso8601(value)
  rescue Date::Error
    errors.add(
      attribute,
      "must use a valid date"
    )
    nil
  end

  def local_midnight(date, attribute)
    workspace.local_time_at(date, 0)
  rescue Workspace::InvalidLocalTime => error
    errors.add(attribute, error.message)
    nil
  end

  def parse_local_datetime(value, attribute)
    workspace.parse_local_datetime(value)
  rescue Workspace::InvalidLocalTime => error
    errors.add(attribute, error.message)
    nil
  end

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(
      :ends_at,
      "must be later than the start time"
    )
  end

  def ends_in_the_future
    return unless ends_at
    return if ends_at > Time.current

    errors.add(
      :ends_at,
      "must be in the future"
    )
  end

  def resource_belongs_to_workspace
    return unless shared_resource && workspace
    return if shared_resource.workspace_id == workspace_id

    errors.add(
      :shared_resource,
      "must belong to this workspace"
    )
  end

  def creator_can_manage_scope
    return unless created_by&.persisted? &&
      workspace&.persisted?

    membership = workspace.memberships.find_by(
      user_id: created_by_id
    )

    allowed = if workspace_wide?
      membership&.owner?
    else
      membership&.can_manage_resources?
    end

    return if allowed

    message = if workspace_wide?
      "Only the workspace owner can add a workspace-wide blackout."
    else
      "Only workspace owners and managers can add a resource blackout."
    end

    errors.add(:base, message)
  end

  def time_zone_identifier_is_valid
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(
      :time_zone,
      "must be a valid IANA time zone"
    )
  end

  def all_day_boundaries_are_local_midnights
    return unless all_day?
    return if starts_at.blank? ||
      ends_at.blank? ||
      time_zone.blank?

    zone = ActiveSupport::TimeZone[time_zone]
    return unless zone

    local_start = starts_at.in_time_zone(zone)
    local_end = ends_at.in_time_zone(zone)

    return if local_midnight?(local_start) &&
      local_midnight?(local_end)

    errors.add(
      :base,
      "An all-day blackout must begin and end at local midnight."
    )
  end

  def local_midnight?(time)
    time.hour.zero? &&
      time.min.zero? &&
      time.sec.zero?
  end

  def does_not_overlap_existing_blackout
    return unless conflict_checkable?

    return unless ScheduleBlock.blackout_conflict?(
      workspace: workspace,
      shared_resource: shared_resource,
      starts_at: starts_at,
      ends_at: ends_at,
      excluding_blackout_period_id: id
    )

    errors.add(:base, OVERLAP_MESSAGE)
  end

  def does_not_overlap_confirmed_reservation
    return unless conflict_checkable?

    return unless ScheduleBlock.reservation_conflict?(
      workspace: workspace,
      shared_resource: shared_resource,
      starts_at: starts_at,
      ends_at: ends_at
    )

    errors.add(
      :base,
      RESERVATION_CONFLICT_MESSAGE
    )
  end

  def conflict_checkable?
    workspace&.persisted? &&
      starts_at.present? &&
      ends_at.present? &&
      ends_at > starts_at
  end

  def create_schedule_block
    ScheduleBlock.block_for!(self)
  end

  def sync_schedule_block
    schedule_block.update!(
      workspace: workspace,
      shared_resource: shared_resource,
      starts_at: starts_at,
      ends_at: ends_at,
      active: true
    )
  end

  def schedule_block_changed?
    saved_change_to_workspace_id? ||
      saved_change_to_shared_resource_id? ||
      saved_change_to_starts_at? ||
      saved_change_to_ends_at?
  end
end
