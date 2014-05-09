require 'spec_helper'

describe BsParser do

	it 'can open a pdf' do
		BsParser.get_text("#{File.dirname(__FILE__)}/resources/p1.PDF")
	end	
end