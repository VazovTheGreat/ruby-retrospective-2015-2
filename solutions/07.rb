module LazyMode
  class Date
    D = 1
    M = 30
    W = 7
    def initialize(date)
      split_date = date.split('-')
      @year = split_date[0].to_i
      @month = split_date[1].to_i
      @day = split_date[2].to_i
    end

    def year
      @year
    end

    def month
      @month
    end

    def day
      @day
    end

    def add_days(days)
      new_years = days / 365 + @year
      days_after_years = days % 365
      new_months = days_after_years / 30 + @month
      new_days = days_after_years % 30 + @day
      new_date = HelperDate.format_date new_years, new_months, new_days
      Date.new "%d-%d-%d" % [new_date[0], new_date[1], new_date[2]]
    end

    def self.to_days(elements, type)
      elements = elements.to_i
      elements * self.const_get(type.upcase)
      # elements * (type == 'd' ? elements : (type == 'w') ? elements * 7 :
      # elements * 30)
      # case type
      #   when 'd'
      #     elements
      #   when 'w'
      #       elements * 7
      #   when 'm'
      #     elements * 30
      # end
    end

    def -(other)
      (@year - other.year) * 360 +
          (@month - other.month) * 30 +
          (@day - other.day)
    end

    def to_s
      "%04d-%02d-%02d" % [@year, @month, @day]
    end
  end

  class File
    attr_reader :notes, :name
    attr_writer :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(header, *tags, &block)
      note = Note.new header, *tags, &block
      include_note note
    end

    def include_note(note)
      note.file_name @name
      @notes << note
      note.sub_notes.each { |n| include_note n }
    end

    def daily_agenda(date)
      Agenda.new agenda(date, 0)
    end

    def weekly_agenda(date)
      agenda_notes = []
      0.upto(6).each do |index|
        agenda_notes << agenda(date.add_days(index), 0)
      end
      Agenda.new agenda_notes.flatten!
    end

    private
    def agenda(date, period)
      agenda = []
      @notes.each do |note|
        try_add_note note, date, period, agenda
      end
      agenda
    end

    def try_add_note(note, date, period, agenda)
      difference = (date - note.scheduled)
      HelperFile.add_note_diff_first note, difference, period, agenda
      HelperFile.add_note_diff_second note, difference, period, agenda
      HelperFile.add_note_diff_third note, difference, period, agenda
    end

  end

  class HelperFile
    def self.add_note_diff_first (note, difference, period, agenda)
      if difference <= 0 && difference + period >= 0
        note.date(note.scheduled.to_s)
        agenda << note
      end
    end

    def self.add_note_diff_second (note, difference, period, agenda)
      if difference > 0 && ! note.repetition.nil? \
         && (difference % note.repetition == 0)
        note.date(note.scheduled.add_days(difference).to_s)
        agenda << note
      end
    end

    def self.add_note_diff_third (note, difference, period, agenda)
      if difference > 0 && ! note.repetition.nil? \
        && (difference % note.repetition) + period >= note.repetition
        total = difference + (note.repetition - difference % note.repetition)
        note.date(note.scheduled.add_days(total).to_s)
        agenda << note
      end
    end
  end


  class HelperDate
    def self.format_date (years, months, days)
      if days > 30
        days -= 30
        months += 1
      end
      [*format_year(years, months), days]
    end

    def self.format_year(years, months)
      if months > 12
        months -= 12
        years += 1
      end
      [years, months]
    end
  end

  class Agenda
    attr_reader :notes
    def initialize(notes)
      @notes = notes
    end

    def where(option = {})
      filtered_notes =  @notes.select do |note|
        is_included? note, option
      end
      self.class.new filtered_notes.to_a
    end

    def is_included?(note, option)
      include = true
      (include &&= note.tags.include? option[:tag]) unless option[:tag].nil?
      (include &&= (note.header.match(option[:text]) || \
                     note.body.match(option[:text]))) unless option[:text].nil?
      (include &&= note.status == option[:status]) unless option[:status].nil?
      include
    end
  end



  def self.create_file(name, &block)
    file = File.new name
    file.instance_eval &block if block_given?
    file
  end



  class Note
    attr_reader :sub_notes, :repetition

    def initialize(header, *tags, &block)
      @header = header
      @tags = tags
      @status = :topostpone
      set_default
      if block_given?
        instance_eval &block
      end
    end

    def set_default
      @body = ''
      @sub_notes = []
      @date = nil
      @repetition = nil # day based
    end

    def note(header, *tags, &block)
      note = Note.new header, *tags, &block
      @sub_notes << note
    end

    def scheduled(date = nil)
      parse_scheduled date
    end

    def date(date = nil)
      parse_scheduled date
    end

    def parse_scheduled(date)
      parse_date = (date || "").split(' ')
      if parse_date.length == 2
        repetition = parse_date[1].match(/^\+(\d+)([mdw])$/).captures
        @repetition = Date.to_days repetition[0], repetition[1]
      end
      parse_date[0] = Date.new(parse_date[0]) unless parse_date[0].nil?
      set_get_attribute :@date, parse_date[0]
    end


    def method_missing (name, *args)
      args = nil if args == []
      set_get_attribute "@#{name}", *args
    end

    def set_get_attribute(attribute_name, value = nil)
      instance_variable_set attribute_name, value unless value.nil?
      instance_variable_get attribute_name
    end

  end
end