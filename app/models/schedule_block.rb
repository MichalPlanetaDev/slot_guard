class ScheduleBlock < ApplicationRecord
  belongs_to :workspace
  belongs_to :shared_resource,
    optional: true
  belongs_to :reservation,
    optional: true,
    inverse_of: :schedule_block
  belongs_to :blackout_period,
    optional: true,
    inverse_of: :schedule_block

  validates :starts_at, :ends_at, presence: true

  validate :ends_after_start
  validate :has_exactly_one_source
  validate :matches_its_source

  scope :active, -> { where(active: true) }
  scope :overlapping, ->(starts_at, ends_at) {
    where(
      <<~SQL.squish,
        tsrange(
          schedule_blocks.starts_at,
          schedule_blocks.ends_at,
          '[)'
        ) &&
        tsrange(
          CAST(? AS timestamp),
          CAST(? AS timestamp),
          '[)'
        )
      SQL
      starts_at,
      ends_at
    )
  }

  class << self
    def reserve_for!(reservation)
      create!(
        workspace: reservation.shared_resource.workspace,
        shared_resource: reservation.shared_resource,
        reservation: reservation,
        starts_at: reservation.starts_at,
        ends_at: reservation.ends_at,
        active: reservation.confirmed?
      )
    end

    def block_for!(blackout_period)
      create!(
        workspace: blackout_period.workspace,
        shared_resource: blackout_period.shared_resource,
        blackout_period: blackout_period,
        starts_at: blackout_period.starts_at,
        ends_at: blackout_period.ends_at,
        active: true
      )
    end

    def blackout_conflict?(
      workspace:,
      shared_resource:,
      starts_at:,
      ends_at:,
      excluding_blackout_period_id: nil
    )
      conflicts = conflicting_with(
        workspace: workspace,
        shared_resource: shared_resource,
        starts_at: starts_at,
        ends_at: ends_at
      ).where.not(blackout_period_id: nil)

      if excluding_blackout_period_id
        conflicts = conflicts.where.not(
          blackout_period_id: excluding_blackout_period_id
        )
      end

      conflicts.exists?
    end

    def reservation_conflict?(
      workspace:,
      shared_resource:,
      starts_at:,
      ends_at:,
      excluding_reservation_id: nil
    )
      conflicts = conflicting_with(
        workspace: workspace,
        shared_resource: shared_resource,
        starts_at: starts_at,
        ends_at: ends_at
      ).where.not(reservation_id: nil)

      if excluding_reservation_id
        conflicts = conflicts.where.not(
          reservation_id: excluding_reservation_id
        )
      end

      conflicts.exists?
    end

    private

    def conflicting_with(
      workspace:,
      shared_resource:,
      starts_at:,
      ends_at:
    )
      conflicts = active
        .where(workspace_id: workspace.id)
        .overlapping(starts_at, ends_at)

      return conflicts unless shared_resource

      conflicts.where(
        "shared_resource_id IS NULL OR shared_resource_id = ?",
        shared_resource.id
      )
    end
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(
      :ends_at,
      "must be later than the start time"
    )
  end

  def has_exactly_one_source
    return if [ reservation, blackout_period ].compact.one?

    errors.add(
      :base,
      "A schedule block must belong to exactly one scheduling record."
    )
  end

  def matches_its_source
    if reservation
      matches_reservation
    elsif blackout_period
      matches_blackout_period
    end
  end

  def matches_reservation
    expected_workspace = reservation.shared_resource.workspace

    unless workspace_id == expected_workspace.id &&
        shared_resource_id == reservation.shared_resource_id &&
        starts_at == reservation.starts_at &&
        ends_at == reservation.ends_at &&
        active == reservation.confirmed?
      errors.add(
        :base,
        "The schedule block must match its reservation."
      )
    end
  end

  def matches_blackout_period
    unless workspace_id == blackout_period.workspace_id &&
        shared_resource_id == blackout_period.shared_resource_id &&
        starts_at == blackout_period.starts_at &&
        ends_at == blackout_period.ends_at &&
        active?
      errors.add(
        :base,
        "The schedule block must match its blackout period."
      )
    end
  end
end
