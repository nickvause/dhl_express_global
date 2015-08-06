require 'spec_helper'
require 'dhl_express_global'

describe DhlExpressGlobal::Request::Rate do
  describe 'ship service' do
    let(:dhl) { DhlExpressGlobal::Shipment.new(dhl_credentials) }
    let(:shipper) do 
      { :name => "Sender", :company => "Company", :phone_number => "555-555-5555", :address => "35 Great Jones St", :city => "New York", :state => "NY", :postal_code => "10012", :country_code => "US" }
    end
    let(:recipient) do
      { :name => "Recipient", :company => "Company", :phone_number => "555-555-5555", :address => "Bruehlstrasse, 10", :city => "Ettingen", :state => "CH", :postal_code => "4107", :country_code => "CH" }
    end
    let(:packages) do
      [
        {
          :weight => { :units => "KG", :value => 2.86 },
          :dimensions => { :length => 40, :width => 30, :height => 20, units: "CM" }
        }
      ]
    end

    context "international rate request", :vcr do
      let(:options) do
        {
          shipper: shipper,
          recipient: recipient,
          packages: packages,
          payment_info: "DDP"
        }
      end

      it "succeeds" do
        expect {
          @rate = dhl.rate(options)
        }.to_not raise_error

        expect(@rate.class).to_not eq(DhlExpressGlobal::RateError)
      end

    end

  end
end