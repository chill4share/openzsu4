module ZSU::Isolate
  @hidden_entities = []
  def self.start
    model = Sketchup.active_model
    sel = model.selection.to_a
    @hidden_entities = []
    ZSU.start
    ZSU::Model.active_entities.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if e.hidden?
      next if sel.include?(e)
      e.hidden = true
      @hidden_entities << e
    end
    ZSU.commit
  end
  def self.stop
    return if @hidden_entities.empty?
    ZSU.start
    @hidden_entities.each do |e|
      next unless e.valid?
      e.hidden = false
    end
    ZSU.commit
    @hidden_entities = []
  end
end