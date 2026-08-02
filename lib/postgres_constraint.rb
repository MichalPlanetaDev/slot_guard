module PostgresConstraint
  EXCLUSION_VIOLATION = "23P01"

  module_function

  def exclusion_violation?(error)
    sqlstate(error) == EXCLUSION_VIOLATION
  end

  def name(error)
    error_field(
      error,
      PG::Result::PG_DIAG_CONSTRAINT_NAME
    )
  end

  def sqlstate(error)
    error_field(
      error,
      PG::Result::PG_DIAG_SQLSTATE
    )
  end

  def error_field(error, field)
    cause = error.cause
    return unless cause.respond_to?(:result)

    cause.result&.error_field(field)
  end
  private_class_method :error_field
end
