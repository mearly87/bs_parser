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

	def self.values(string_locs)
	    string_locs.reject{|loc| !loc.keyword? }.collect do |loc|
	      loc.to_s.enum_for(:scan, StringLoc::KEYWORD_REGEX)
	      .map { |debit_header, credit_header, date_header, check_header,amount_header, balance_header, date, amount, description|
	          match = debit_header || credit_header || date_header || balance_header || date || amount || check_header || amount_header || description
	          loc.split(loc.to_s.index(match), match.length)
	      }.reject {|match| match.empty?}
	    end.flatten.sort_by(&:left).inject({}){ |value_cols, string_loc|
	      if !value_cols.empty? && new_range = string_loc.vertical_overlap(value_cols.keys.last)
	        value_cols[new_range] = value_cols.delete(value_cols.keys.last) << string_loc
	      else
	        value_cols[[string_loc.left, string_loc.right]] = [string_loc]
	      end
	      value_cols
	      }
	      .flat_map { |key, value| 
	        column_type = :unknown
	        value.sort_by(&:top).collect do |trans|
	          column_type = trans.set_type_by_column(column_type)
	          trans
	        end
	      }.flatten.sort_by(&:top).inject({}){ |trans_rows, string_loc|
	      if !trans_rows.empty? && new_range = string_loc.horizontal_overlap(trans_rows.keys.last)
	        trans_rows[new_range] = trans_rows.delete(trans_rows.keys.last) << string_loc
	      else
	        trans_rows[[string_loc.top, string_loc.bottom]] = [string_loc]
	      end
	      trans_rows
	    }
    end

    def self.transactions(string_locs)
	    values(string_locs).map{|key, values| 
	      top,bottom,left,right,type,amount = 10000000,0,1000000,0,nil,nil
	      values.sort_by(&:left).each do |value| 
	        top = value.top if top > value.top
	        bottom = value.bottom if bottom < value.bottom
	        left = value.left if left > value.left
	        right = value.right if right < value.right
	        type, amount = value.get_type_by_row(type, amount)
	      end
	      [top,bottom,left,right,type,amount]
	    }.reject {|trans| !trans[5] }
    end
end
