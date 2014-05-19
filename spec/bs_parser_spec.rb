require 'spec_helper'

describe BsParser do

	it 'can open a pdf' do
		BsParser.get_text("#{File.dirname(__FILE__)}/resources/wf_bank.pdf").each do |page|
			page.each do |transaction|
				puts "#{transaction[4]}: #{transaction[5]} #{transaction.inspect}"
			end
		end
	end

end