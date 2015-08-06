require 'dhl_express_global/request/base'

module DhlExpressGlobal
  module Request
    class Rate < Base

      def initialize(credentials, options={})
        super
      end

      def process_request
        api_response = self.class.post api_url, :body => build_xml, :headers => headers
        puts api_response if @debug
        response = parse_response(api_response)
        if success?(response)
          success_response(response)
        else
          failure_response(response)
        end
      end

      private

      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml[:soapenv].Envelope( 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/", 
                                  'xmlns:ship' => "http://scxgxtt.phx-dc.dhl.com/euExpressRateBook/RateMsgRequest") {
            add_ws_authentication_header(xml)
            xml[:soapenv].Body {
              xml.RateRequest {
                xml.parent.namespace = nil
                xml.RequestedShipment {
                  xml.DropOffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
                  xml.NextBusinessDay @shipping_options[:next_day] ||= "N"
                  xml.Ship {
                    add_shipper(xml)
                    add_recipient(xml)
                  }
                  add_requested_packages(xml)
                  xml.PaymentInfo @payment_info
                  xml.Account @credentials.account_number
                }
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def add_shipper(xml)
        xml.Shipper {
          add_address_street_lines(xml, @shipper[:address])
          xml.City @shipper[:city]
          xml.PostalCode @shipper[:postal_code]
          xml.StateOrProvinceCode @shipper[:state] if @shipper[:state]
          xml.CountryCode @shipper[:country_code]
        }
      end

      def add_recipient(xml)
        xml.Recipient {
          add_address_street_lines(xml, @recipient[:address])
          xml.City @recipient[:city]
          xml.PostalCode @recipient[:postal_code]
          xml.StateOrProvinceCode @recipient[:state] if @recipient[:state]
          xml.CountryCode @recipient[:country_code]
        }
      end

      def headers
        super.merge!("SOAPAction" => "euExpressRateBook_providerServices_ShipmentHandlingServices_Binder_getRateRequest")
      end
      ## <RateRequest> 
      ##   <ClientDetail></ClientDetail>
      ##   <RequestedShipment>
      ##     <DropOffType>REQUEST_COURIER</DropOffType>
      ##     <Ship>
      ##       <Shipper>
      ##         <StreetLines>1-16-24, Minami-gyotoku</StreetLines>
      ##         <City>Ichikawa-shi, Chiba</City>
      ##         <PostalCode>272-0138</PostalCode>
      ##         <CountryCode>JP</CountryCode>
      ##       </Shipper>
      ##       <Recipient>
      ##         <StreetLines>63 RENMIN LU, QINGDAO SHI</StreetLines>
      ##         <City>QINGDAO SHI</City>
      ##         <PostalCode>266033</PostalCode>
      ##         <CountryCode>CN</CountryCode>
      ##       </Recipient>
      ##     </Ship>
      ##     <Packages>
      ##       <RequestedPackages number="1">
      ##         <Weight>
      ##           <Value>2.0</Value>
      ##         </Weight>
      ##         <Dimensions>
      ##           <Length>13</Length>
      ##           <Width>12</Width>
      ##           <Height>9</Height>
      ##         </Dimensions>
      ##       </RequestedPackages>
      ##     </Packages>
      ##     <ShipTimestamp>2010-11-26T12:00:00GMT-06:00</ShipTimestamp>
      ##     <UnitOfMeasurement>SU</UnitOfMeasurement>
      ##     <Content>NON_DOCUMENTS</Content>
      ##     <DeclaredValue>0000000200</DeclaredValue>
      ##     <DeclaredValueCurrecyCode>USD</DeclaredValueCurrecyCode>
      ##     <PaymentInfo>DDP</PaymentInfo>
      ##     <Account>000000000</Account>
      ##   </RequestedShipment>
      ## </RateRequest>
    end
  end
end