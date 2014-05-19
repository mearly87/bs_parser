require 'bs_parser/version'
require 'bs_parser/string_loc'
require 'pdf-reader'

module BsParser
	  def self.get_text(filename)
	  	File.open(filename, 'rb') do |file|
          receiver = PDF::Reader::PageTextReceiver.new
          reader = PDF::Reader.new(file)
          transactions = reader.pages.collect do |page|

	          receiver = PDF::Reader::PageTextReceiver.new
	          mediabox = page.attributes[:MediaBox]
          	  width  = mediabox[2] - mediabox[0]
          	  height = mediabox[3] - mediabox[1]
	          page.walk(receiver)
	          text_runs = receiver.instance_variable_get("@characters")
	          transactions(generate_string_loc(height, text_runs))
	      end
	    end
	  end

	  def self.generate_string_loc(height, chars)
	  	page_text = SortedSet.new;
	    text_block = StringLoc.new
	    word = StringLoc.new
	    collect_lines(get_chars(height, chars).sort_by(&:top))
	    .flat_map do |key, value| 
	      value.sort_by(&:left)
	      .collect do |loc|  
	        if loc.is_space? && !word.empty?
	          if match = word.is_keyword?
	            page_text << text_block
	            text_block = StringLoc.new
	            page_text << word
	          else
	            text_block << word
	          end
	          word = StringLoc.new
	        end
	        if word.near? loc, 0.5
	          word << loc
	        elsif word.near? loc, 1.5
	          word.text += ' '
	          word << loc
	        else
	          text_block << word
	          page_text << text_block
	          text_block = StringLoc.new
	          word = StringLoc.new
	          word << loc
	        end
	      end
	    end
	    page_text.to_a
	  end

	  def self.get_chars height, chars
		  chars.collect do |char|
		    next unless char.text
		    loc = StringLoc.new_from_textrun(char, height)
		  end.reject {|loc| loc.nil? || loc.left.nil? || loc.top.nil?}
	  end

	  def self.collect_lines(string_locs)
	  	string_locs.inject({}) do |value_cols, string_loc|
	        if !value_cols.empty? && new_range = string_loc.horizontal_overlap(value_cols.keys.last)
	          value_cols[new_range] = value_cols.delete(value_cols.keys.last) << string_loc
	        else
	          value_cols[[string_loc.top, string_loc.bottom]] = [string_loc]
	        end
	        value_cols
	     end
	  end

    def self.transactions(string_locs)
    	curr_header = nil
	    group_keywords_by_row(find_keywords(string_locs)).map{|key, values| 
	      values.sort_by!(&:left)
	      top,bottom,left,right,type,amount = 10000000,0,1000000,0,nil,nil
	      mapped_values = zip_values(curr_header, values)
	      if !mapped_values || mapped_values.none? {|value| value[1] && value[1].is_amount? }
	      	curr_header = values
	      	nil
	      	next
	      end
	      mapped_values.each do |header, value| 
	      	next unless value
	        top = value.top if top > value.top
	        bottom = value.bottom if bottom < value.bottom
	        left = value.left if left > value.left
	        right = value.right if right < value.right
	        type, amount = value.get_type_by_row(type, amount, header, values, curr_header)
	      end
	      [top,bottom,left,right,type,amount]
	    }.reject {|trans| trans.nil? || !trans[5] }
    end

    def self.header?(row)
    	row.none?{|cell| cell.is_amount?}
    end

    def self.zip_values(header_row, value_row)
    	value_row = value_row.sort_by(&:left)
    	return unless header_row
    	i = 0
    	header_row.collect do |header|
    		value = value_row.find do |value|
    			header.vertical_overlap([value.left, value.right])
    		end
    		[header, value]
    	end

    end

    def self.find_keywords(string_locs)
    	string_locs.reject{|loc| !loc.keyword? }.collect do |loc|
	      loc.to_s.enum_for(:scan, StringLoc::KEYWORD_REGEX)
	      .map { |debit_header, credit_header, date_header, check_header,amount_header, balance_header, date, amount, description|
	          match = debit_header || credit_header || date_header || balance_header || date || amount || check_header || amount_header || description
	          loc.split(loc.to_s.index(match), match.length)
	      }.reject {|match| match.empty?}
	    end.flatten
	end

	def self.group_keywords_by_row(keywords)
	    keywords.sort_by(&:top).inject({}) do |trans_rows, string_loc|
	      if !trans_rows.empty? && new_range = string_loc.horizontal_overlap(trans_rows.keys.last)
	        trans_rows[new_range] = trans_rows.delete(trans_rows.keys.last) << string_loc
	      else
	        trans_rows[[string_loc.top, string_loc.bottom]] = [string_loc]
	      end
	      trans_rows
	    end
	end
end
