class RemoteBurndown
  attr_accessor :data

  def initialize(settings, board_id, is_init)
    @settings = settings
    @board_id = board_id
    @data = {
      'meta' => {
        'board_id' => @board_id,
        'sprint' => 1,
        'total_days' => 10,
        'weekend_lines' => [3.5, 8.5]
      },
      'days' => []
    }
    write_data if is_init
  end

  def update
    read_data

    burndown_data = init_burndown_data
    update_data(burndown_data)

    write_data
  end

  def read_data
    trello = TrelloWrapper.new(@settings)
    board = trello.board(@board_id)

    burndown_card = find_burndown_chart_card(board)

    @data = get_data_from_yaml_block(burndown_card)
  end

  def write_data
    @data['days'].each do |day|
      %w[story_points_extra tasks_extra].each do |key|
        day.delete key if day[key] && (day[key]['done']).zero?
      end
    end

    trello = TrelloWrapper.new(@settings)
    board = trello.board(@board_id)
    burndown_card = find_burndown_chart_card(board)

    trello.set_description(burndown_card.id, "```yaml\n#{@data.to_yaml}```")
  end

  def update_data(burndown_data)
    new_entry = burndown_data.to_hash

    if entry_exists?(burndown_data.date_time.to_date) && @data['days'].empty?
      replace_entry(burndown_data.date_time.to_date, new_entry)
    else
      @data['days'].push(new_entry)
    end
  end

  private

  def find_burndown_chart_card(board)
    board.done_column.cards.find do |card|
      card.name.casecmp('burndown chart').zero?
    end
  end

  def get_data_from_yaml_block(burndown_card)
    raw_yaml_block = burndown_card.desc.match(/(```[a-z]*\n[\s\S]*?\n```)/)[1]
    yaml_block = raw_yaml_block.match(/```yaml([\s\S]*)```/)[1]
    YAML.safe_load(yaml_block)
  end

  def init_burndown_data
    burndown_data = BurndownData.new(@settings)
    burndown_data.board_id = @board_id
    burndown_data.fetch

    burndown_data
  end

  def entry_exists?(date)
    @data['days'].any? { |entry| entry['date'] == date.to_s }
  end

  def replace_entry(date, new_entry)
    @data['days'].each_with_index do |entry, idx|
      @data['days'][idx] = new_entry if entry['date'] == date.to_s
    end
  end
end
