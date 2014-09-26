class StringLoc
  include Comparable

  attr_accessor :right, :top, :bottom, :left, :font_size, :text, :type

  DATE_REGEX = /(?:[0-9]+\/[0-9]+)|(?:[0-9]{1,2}\s*-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))/
  AMOUNT_REGEX = /[0-9]+?.?[0-9]*\.[0-9]{2}/

  VALUE_REGEX = /(?<date>(?:[0-9]+\/[0-9]+)|(?:[0-9]{1,2}\s*-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)))
                |(?<amount>[0-9]+?.?[0-9]*\.[0-9]{2})/


  def self.create_new(character, l, r, t, b)
    str_loc = StringLoc.new

    str_loc.right = r
    str_loc.left = l
    str_loc.bottom = b
    str_loc.top = t
    str_loc.text = character
    str_loc.set_type
    return str_loc
  end

  def self.new_from_textrun(char, page_height)
    if char.is_a? REXML::Element
      return StringLoc.create_new(char.text, char.attributes["l"], char.attributes["r"], line.attributes["t"], line.attributes["b"])
    end

    str_loc = StringLoc.new

    str_loc.right = char.x + char.width
    str_loc.left = char.x
    str_loc.bottom = page_height - char.y + char.font_size
    str_loc.top = page_height - char.y
    str_loc.text = char.text
    str_loc.set_type
    return str_loc
  end

  def <<(loc)
    combine(loc)
  end

  def combine(loc, sep='')

    if !loc.is_space?
      self.left = loc.left if !self.left || loc.left < self.left
      self.right = loc.right if !self.right || loc.right > self.right
      self.top = loc.top if !self.top || loc.top < self.top
      self.bottom = loc.bottom if !self.bottom || loc.bottom > self.bottom
    end
    self.text ||= ''
    self.text += sep + "#{loc.text}"
    self
  end

  def add_all(locs)
  	locs.each do |loc|
  		self << loc
    end
	end
  
  def width
    return self.right - self.left
  end

  def empty?
  	!text  or text.empty?
  end

  def header?
    match = to_s.match(HEADER_REGEX)
    return match unless match.to_s.empty?
  end

  def value?
    match = to_s.match(VALUE_REGEX)
    return match unless match.to_s.empty?
  end

  def set_type
    match = to_s.match(KEYWORD_REGEX)
    return nil unless match
    self.type = :debit_header if match[:debit_header]
    self.type = :credit_header if match[:credit_header]
    self.type = :check_header if match[:check_header]
    self.type = :date_header if match[:date_header]
    self.type = :balance_header if match[:balance_header]
    self.type = :amount_header if match[:amount_header]
    self.type = :date if match[:date]
    self.type = :amount if match[:amount]
    self.type
  end

    HEADER_REGEX = %r{(?:
        # debits
        (?<debit_header>(?:debit)|(?:amount\s?(?:(?:subtracted)|(?:debited)))|(?:withdrawls(?:\/debits)?))|
        # credits
        (?<credit_header>(?:credits)|(?:credit)|(?:amount\s?(?:(?:added)|(?:credited)))|(?:desposits)|(?:deposits\/credits))|
        # date
        (?<date_header>(?:date)|(?:date posted)|(?:posted date)|(?:dates))|
        # description
        )}xi
#         (?<description>description)

  KEYWORD_REGEX = %r{(?:
        (?<debit_header>(?:fee)|(?:payment)|(?:debit)|(?:amount?\s?(?:(?:subtracted)|(?:debited)))|(?:withdrawal(?:s?))|(?:withdrawl(?:s?)(?:\/debit(?:s?))?))|
        (?<credit_header>(?:credit(?:s?))|(?:amount\s?(?:(?:added)|(?:credited)))|(?:deposit(?:s?))|(?:deposit(?:s?)\/credit(?:s?)))|
        (?<date_header>(?:date)|(?:date posted)|(?:posted date)|(?:dates))|
        (?<check_header>check(?!ing))|
        (?<amount_header>amount)|
        (?<balance_header>balance)|
        (?<date>(?:[0-9]+\/[0-9]+)|(?:[0-9]{1,2}\s*-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))(?:.(?:[0-9]+\/[0-9]+))?)|
        (?<amount>[0-9]+?.?[0-9]*\.[0-9]{2})
        )}xi
  

  def is_keyword?
    is_amount? or is_date?
  end

  def keyword?
    to_s.match(KEYWORD_REGEX)
  end

  def is_date?
  	to_s.match(DATE_REGEX)
  end

  def is_amount?
  	to_s.match(AMOUNT_REGEX)
  end

  def date_header?
    to_s.match(/(?:date)|(?:date posted)|(?:posted date)|(?:dates)/i)
  end

  def to_s
  	text.to_s
  end

  def split(start_index, end_index)
    char_size = (self.right - self.left) / to_s.length

    StringLoc.create_new(to_s[start_index,end_index], 
     (left + start_index*char_size), (left + (start_index + end_index)*char_size),
     self.top, self.bottom)
  end

# PUT IN MODULE
	def <=>(loc2)
		return 0 if !self.left || !self.top || !loc2.left || !loc2.top
    top = self.top - loc2.top
		left = self.left - loc2.left
	    if top != 0
	      return top;
	    end
	    if left != 0
	      return left;
	    end
	    return 0;
	end

  def char_size
    avg_size = width / text.length if text
    avg_size ||= 1
    Math.sqrt(avg_size * (self.bottom - self.top)) / 2
  end

	def near?(loc2, error=1.5)
 		!far_right?(loc2, error) && !far_left?(loc2,error) && !above?(loc2) && !under?(loc2)
	end

	def above?(loc2)
    return self.top && loc2.bottom && self.bottom && loc2.top && self.top < loc2.top && self.bottom < loc2.bottom
	end

	def under?(loc2)
		return self.top && loc2.bottom && self.bottom && loc2.top && self.top > loc2.top && self.bottom > loc2.bottom
	end

  def far_right?(loc2, error=1.5)
    return false unless self.right && loc2.left
    #puts "#{self.text} + #{loc2.text}: #{self.left} - #{char_size * 1.5} < #{loc2.right} = #{(self.left - char_size)  > loc2.right}"  
    return self.right && loc2.left && (self.left - char_size * error) > loc2.right
  end

  def far_left?(loc2, error=1.5)
    return false unless self.right && loc2.left
    #puts "#{self.text} + #{loc2.text}: #{self.right} + #{char_size * 1.5} < #{loc2.left} = #{(self.right + char_size)  < loc2.left}"
    return self.left && loc2.right && (self.right + char_size  * error)  < loc2.left
  end

  def after?(loc2)
    return false unless self.right && loc2.left
    return self.right && loc2.left && self.left > loc2.right
  end

  def before?(loc2)
    return false unless self.right && loc2.left
    return self.left && loc2.right && self.right  < loc2.left
  end

  #return true if they overlap and the length of theoverlap is more than 25% of the shorter line
  def vertical_overlap(range)
    #puts "#{to_s} #{self.right} > #{range[0]} && #{self.left} < #{range[1]}, overlap: #{[self.right, range[1]].min - [self.left, range[0]].max}, short length: #{[self.right - self.left,range[1]-range[0]].min}, 25%: #{([self.right - self.left,range[1]-range[0]].min * 0.25)}"
    return [[range[0], self.left].min, [range[1], self.right].max] if self.right > range[0] && self.left  < range[1] && [self.right, range[1]].min - [self.left, range[0]].max > ([self.right - self.left,range[1]-range[0]].min * 0.25)
  end

  #return true if they overlap and the length of theoverlap is more than 25% of the shorter line
  def horizontal_overlap(range)
    #puts "#{to_s} #{self.right} > #{range[0]} && #{self.left} < #{range[1]}, overlap: #{[self.right, range[1]].min - [self.left, range[0]].max}, short length: #{[self.right - self.left,range[1]-range[0]].min}, 25%: #{([self.right - self.left,range[1]-range[0]].min * 0.25)}"
    return [[range[0], self.top].min, [range[1], self.bottom].max] if self.bottom > range[0] && self.top  < range[1] && [self.bottom, range[1]].min - [self.top, range[0]].max > ([self.bottom - self.top,range[1]-range[0]].min * 0.50)
  end
  def middle
    return -1  unless self.top && self.bottom
    (self.top + self.bottom) / 2
  end


  def is_space?
    to_s.empty? || (/\A\s+\Z/).match(to_s)
  end

  def get_type_by_row(row_type, amount, header, row, curr_header)
    if self.to_s.index('_header')
      return row_type || :header, amount
    else
      case header.type.to_sym
      when :amount_header
          row_type ||= :amount
          return row_type, self.to_s
        when :debit_header
          if row_type == :credit
            return :summary, amount
          else
            return :debit, self.to_s
          end
        when :credit_header
          if row_type == :debit
            return :summary, amount
          else
            return :credit, self.to_s
          end
        when :balance
          type = row_type || :balance
          amount = self.to_s if type == :balance
          return type, amount
        when :unkown
          type = row_type || :unknown
          if self.is_amount?
            amount ||= value
          end
      end
    end
    return row_type, amount
  end

  def get_type_by_row1(row_type, amount, header, row, curr_header)
    if self.to_s.index('_header')
      return row_type || :header, amount
    else
      case self.type.to_sym
        when :debit
          if row_type == :credit
            return :summary, amount
          else
            return :debit, self.to_s
          end
        when :credit
          if row_type == :debit
            return :summary, amount
          else
            return :credit, self.to_s
          end
        when :check_header
          row_type ||= :check
        when :debit_header
            return row_type || :debit, amount 
        when :credit_header
            return row_type || :credit, amount 
        when :balance_header
            return row_type || :balance, amount 
        when :amount
            return row_type, self.to_s
        when :balance
          type = row_type || :balance
          amount = self.to_s if type == :balance
          return type, amount
        when :unkown
          type = row_type || :unknown
          if self.is_amount?
            amount ||= value
          end
      end
    end
    return row_type, amount
  end

end