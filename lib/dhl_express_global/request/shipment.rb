require 'dhl_express_global/request/base'

module DhlExpressGlobal
  module Request
    class Shipment < Base

      def initialize(credentials, options={})
        super
        requires!(options, :service_type, :payment_info, :international_detail)
        @international_detail = options[:international_detail]
        requires!(@international_detail, :commodities)
        @commodities = @international_detail[:commodities]
        requires!(@commodities, :description, :customs_value)
        @payment_info = options[:payment_info]
        @label_specification = {
          :image_type => 'PDF',
          :label_template => 'ECOM26_84_001'
        }

        @label_specification.merge! options[:label_specification] if options[:label_specification]
      end

      def process_request
        puts api_response if @debug
        response = parse_response(api_response)
        if success?(response)
          success_response(response)
        else
          failure_response(response)
        end
      end

      def api_response
        @response ||= self.class.post(URI(api_url),
          body:    build_xml,
          headers: headers,
          verify: true
        )
      end

      private

      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml[:soapenv].Envelope( 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/", 
                                  'xmlns:ship' => "http://scxgxtt.phx-dc.dhl.com/euExpressRateBook/ShipmentMsgRequest") {
            add_ws_authentication_header(xml)
            xml[:soapenv].Body {
              xml[:ship].ShipmentRequest {
                xml.RequestedShipment {
                  xml.parent.namespace = nil
                  add_shipment_info(xml)
                  xml.ShipTimestamp @shipping_options[:ship_timestamp] ||= (Time.now + 10*60).strftime("%Y-%m-%dT%H:%M:%SGMT%:z")
                  xml.PaymentInfo @payment_info
                  add_international_detail(xml)
                  xml.Ship {
                    add_shipper(xml)
                    add_recipient(xml)
                  }
                  add_requested_packages(xml)
                }
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def add_shipment_info(xml)
        xml.ShipmentInfo do
          xml.DropOffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
          xml.ServiceType @service_type
          xml.Account @credentials.account_number
          xml.Currency @shipping_options[:currency].upcase
          xml.UnitOfMeasurement @shipping_options[:unit_of_measurement]
          if @shipping_options[:paperless_trade_enabled]
            xml.PaperlessTradeEnabled @shipping_options[:paperless_trade_enabled] ? 'true' : 'false'
            if @shipping_options[:request_dhl_customs_invoice]
              xml.LabelOptions do
                xml.RequestDHLCustomsInvoice @shipping_options[:request_dhl_customs_invoice] ? 'Y' : 'N'
              end
            end
          end
          if @shipping_options[:dhl_express_service_code]
            xml.SpecialServices do
              xml.Service do
                xml.ServiceType @shipping_options[:dhl_express_service_code]
              end
            end
          end
        end
      end

      def add_international_detail(xml)
        xml.InternationalDetail {
          xml.Commodities {
            xml.NumberOfPieces @commodities[:number_of_pieces] if @commodities[:number_of_pieces]
            xml.Description @commodities[:description]
            xml.Quantity @commodities[:quantity] if @commodities[:quantity]
            xml.UnitPrice @commodities[:unit_price] if @commodities[:unit_price]
            xml.CustomsValue @commodities[:customs_value]
          }
          @international_detail[:export_declaration]&.tap do |export_declaration|
            xml.ExportDeclaration do
              xml.InvoiceNumber export_declaration[:invoice_number] if export_declaration[:invoice_number]
              xml.InvoiceDate export_declaration[:invoice_date].strftime("%Y-%m-%d") if export_declaration[:invoice_date]
              if export_declaration[:line_items]
                xml.ExportLineItems do
                  export_declaration[:line_items].each do |line_item|
                    xml.ExportLineItem do
                      xml.ItemNumber line_item[:item_number]
                      xml.Quantity line_item[:quantity]
                      xml.QuantityUnitOfMeasurement line_item[:quantity_units]
                      xml.ItemDescription line_item[:description]
                      xml.UnitPrice line_item[:unit_price]
                      xml.NetWeight line_item[:net_weight]
                      xml.GrossWeight line_item[:gross_weight]
                      xml.ManufacturingCountryCode line_item[:country_of_manufacture]
                      xml.CommodityCode line_item[:commodity_code]
                    end
                  end
                end
              end
            end
          end
          xml.Content @international_detail[:content] if @international_detail[:content]
        }
      end

      def add_requested_packages(xml)
        xml.Packages {
          @packages.each_with_index do |package, i|
            xml.RequestedPackages('number' => i + 1) {
              xml.Weight package[:weight][:value]
              xml.Dimensions {
                xml.Length package[:dimensions][:length]
                xml.Width package[:dimensions][:width]
                xml.Height package[:dimensions][:height]
              }
              xml.CustomerReferences @shipping_options[:customer_references] ||= "#{rand(10**10)}"
            }
          end
        }
      end


      def failure_response(response)
        error_message = error_response(response)
        raise RateError, error_message
      end

      def success_response(response)
        @response_details = response[:envelope][:body][:shipment_response]
      end

      def success?(response)
        response[:envelope][:body][:shipment_response] && !error_response(response)
      end

      def error_response(response)
        response[:envelope][:body][:shipment_response][:notification][:message]
      rescue
        response[:envelope][:body][:shipment_response][:notification].first[:message]
      end

      def headers
        super.merge!("SOAPAction" => "euExpressRateBook_providerServices_ShipmentHandlingServices_Binder_createShipmentRequest")
      end

    end
  end
end