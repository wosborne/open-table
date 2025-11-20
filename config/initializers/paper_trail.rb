PaperTrail.config.enabled = true
PaperTrail.config.version_limit = 10  # Keep last 10 versions per variant

# Use JSON serializer to avoid YAML BigDecimal issues
PaperTrail.serializer = PaperTrail::Serializers::JSON

# Track which user made the changes
PaperTrail.request.whodunnit = -> {
  if defined?(current_user) && current_user.present?
    current_user.id
  else
    "System"
  end
}
