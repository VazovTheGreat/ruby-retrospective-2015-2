module SpreadSheetHelper
  FORMULAS = ['ADD', 'MULTIPLY', 'SUBTRACT', 'DIVIDE', 'MOD']
  INFORMATION = {'ADD': [2, 'ge', :+], 'MULTIPLY': [2, 'ge', :*],
                 'SUBTRACT': [2, 'eq', :-], 'DIVIDE': [2, 'eq', :/],
                 'MOD': [2, 'eq', :%]}
  ERRORS = {'eq': ""}

  def is_cell_reference? (index)
    true if parse_index index rescue false
  end

  def is_number?(item)
    true if Float(item) rescue false
  end

  def parse_sheet(sheet)
    rows = sheet.split("\n").select { |item| ! (item =~ /^\s*$/) }.map(&:strip)
    rows.map { |row| row.split(/\t|(?:\ {2,})/) }
  end

  def parse_formula(item)
    formula = /^\ *([A-Z]+)\((.+)\)$/.match(item)
    raise self.class::Error, "Invalid expression '#{item}'" if formula.nil?
    formula_name, parameters = formula.captures
    parameters = evaluate_formula_parameters parameters.split(',').map(&:strip)
    validate_formula INFORMATION[formula_name.to_sym], formula_name, parameters
    evaluate_formula INFORMATION[formula_name.to_sym], formula_name, parameters
  end

  def validate_formula(info, formula_name, parameters)
    if ! FORMULAS.include? formula_name
      raise self.class::Error, "Unknown function '#{formula_name}'"
    else
      validate_formula_helper info, formula_name, parameters
    end
  end

  def validate_formula_helper(info, formula_name, parameters)
    if parameters.length != info[0] &&  info[1] == 'eq'
      raise self.class::Error, "Wrong number of arguments for '#{formula_name}'\
: expected #{info[0]}, got #{parameters.length}"
    elsif parameters.length < info[0] &&  info[1] == 'ge'
      raise self.class::Error, "Wrong number of arguments for '#{formula_name}'\
: expected at least #{info[0]}, got #{parameters.length}"
    end
  end

  def evaluate_formula (info, formula_name, parameters)
    if info[1] == 'ge'
      result = parameters.reduce(&info[2])
    else
      result = parameters[0].public_send info[2], parameters[1]
    end
    if result == result.floor
      result.to_i.to_s
    else
      '%.2f' % result
    end
  end

  def parse_index(index)
    parsed_index = /^([A-Z]+)([0-9]+)$/.match(index)
    raise self.class::Error, "Invalid cell index '#{index}'"if parsed_index.nil?
    col = parsed_index[1].split("").reverse.map.with_index do |char, power|
      (char.ord - 64) * (26 ** power)
    end.reduce(&:+)
    [Integer(parsed_index[2]) - 1, col - 1]
  end

end


class Spreadsheet
  include SpreadSheetHelper

  def initialize(sheet = '')
    @sheet = parse_sheet sheet
  end

  def empty?
    @sheet.empty?
  end

  def cell_at(cell_index)
    index_vector = parse_index cell_index

    if @sheet.length <= index_vector[0] ||
        @sheet[index_vector[0]].length <= index_vector[1]
      raise Error, "Cell '#{cell_index}' does not exist"
    end
    @sheet[index_vector[0]][index_vector[1]]
  end

  def [](cell_index)
    evaluate_cell cell_at(cell_index)
  end

  def to_s
    @sheet.map do |row|
      row.map { |cell| evaluate_cell cell }.join("\t")
    end.join("\n")
  end

  def evaluate_cell(cell)
    return cell if cell[0] != '='
    if is_number? cell[1..-1]
      cell[1..-1]
    elsif is_cell_reference? cell[1..-1]
      self. [] cell[1..-1]
    else
      parse_formula cell[1..-1]
    end
  end

  def evaluate_formula_parameters parameters
    parameters.map do |item|
      is_cell_reference?(item) ? (self. [] (item)).to_f : item.to_f
    end
  end


  class Error < StandardError
  end

end