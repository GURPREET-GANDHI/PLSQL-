------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------refer [https://slobaray.com/2015/02/05/calling-web-services-from-oracle-plsql/] to understand script
-----------------STEP 1: is to create an ACL entry in Oracle ver 11g
---------------webservice: http://www.webservicex.net/globalweather.asmx?op=GetCitiesByCountry---------

        BEGIN
          dbms_network_acl_admin.create_acl(acl         => 'www.xml',
                                            description => 'Test Sample ACL',
                                            principal   => 'user',
                                            is_grant    => TRUE,
                                            privilege   => 'connect');
          dbms_network_acl_admin.add_privilege(acl       => 'www.xml',
                                               principal => 'user',
                                               is_grant  => TRUE,
                                               privilege => 'resolve');
          dbms_network_acl_admin.assign_acl(acl  => 'www.xml',
                                            host => 'http://www.webservicex.net');
        END;
        /
        
        COMMIT
        
        /
-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
----------------------STEP 2: INVOKE THE SERVICE


Declare
  l_string_request  VARCHAR2(32000);
  l_country_        VARCHAR2(100) := 'PAKISTAN';
  l_http_request    UTL_HTTP.REQ;
  l_http_response   UTL_HTTP.RESP;
  l_buffer_size     NUMBER(10) := 512;
  l_raw_data        RAW(512);
  l_resp_xml        XMLTYPE;
  l_result_xml_node VARCHAR2(128);
  l_cities_         VARCHAR2(128);
  l_namespace_soap  VARCHAR2(128) := 'xmlns="http://www.w3.org/2003/05/soap-envelope"';
  l_clob_response   CLOB;
  l_line            VARCHAR2(128);
  l_substring_msg   VARCHAR2(512);
  l_response_       VARCHAR2(32000); -- xmltype; --
  l_response_text   VARCHAR2(32000);
  str_              Varchar2(32000);
  count_            NUMBER;

BEGIN
  
--------------------------------------------------------------------------
--------------------TAKE THE STRING REQUEST AND PASS THE VARIABLE IN REQUEST
--------------------------------------------------------------------------
          l_string_request := '<?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
          <soap12:Body>
            <GetCitiesByCountry xmlns="http://www.webserviceX.NET">
              <CountryName>' || l_country_ ||
                              '</CountryName>
            </GetCitiesByCountry>
          </soap12:Body>
        </soap12:Envelope>';
        
        
     
--------------------------------------------------------------------------
------------SET UTL VAIABLES
--------------------------------------------------------------------------

  utl_http.set_transfer_timeout(1200);

  l_http_request := utl_http.begin_request(url          => 'http://www.webservicex.net/globalweather.asmx?op=GetCitiesByCountry',
                                           method       => 'POST',
                                           http_version => 'HTTP/1.1');
--------------------------------------------------------------------------
-----------SET HEADER
--------------------------------------------------------------------------

  utl_http.set_header(l_http_request,
                      'Content-Type',
                      'application/soap+xml; charset=utf-8');
  utl_http.set_header(l_http_request,
                      'Content-Length',
                      length(l_string_request));

  <<request_loop>>

      FOR i IN 0 .. ceil(length(l_string_request) / l_buffer_size) - 1 LOOP
        l_substring_msg := substr(l_string_request,
                                  i * l_buffer_size + 1,
                                  l_buffer_size);
      
        BEGIN
          l_raw_data := UTL_RAW.CAST_TO_RAW(l_substring_msg);
        
          UTL_HTTP.WRITE_RAW(r => l_http_request, data => l_raw_data);
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('THIS is an exception');
            EXIT request_loop;
        END;
      END LOOP request_loop;
      
--------------------------------------------------------------------------
---------------GET RESPONSE-----------------------
--------------------------------------------------------------------------


  l_http_response := utl_http.get_response(l_http_request);

          /* 
          
           UTL_HTTP.write_text(l_http_request, l_string_request);
            
             -- get response and obtain received value
           
            l_http_response := utl_http.get_response(l_http_request);
            
            UTL_HTTP.read_text(l_http_response, l_response_text);
            
            dbms_output.put_line(l_response_text);
            dbms_output.put_line('test1');
          --finalizing 
          UTL_HTTP.end_response(l_http_response);
          
          */
          

      dbms_output.put_line('Response> status_code: "' ||
                           l_http_response.status_code || '"');
      dbms_output.put_line('Response> reason_phrase: "' ||
                           l_http_response.reason_phrase || '"');
      dbms_output.put_line('Response> http_version: "' ||
                           l_http_response.http_version || '"');

  BEGIN
    <<response_loop>>
    LOOP
      utl_http.read_raw(l_http_response, l_raw_data, l_buffer_size);
      l_clob_response := l_clob_response ||
                         utl_raw.cast_to_varchar2(l_raw_data);
    END LOOP response_loop;
  EXCEPTION
    WHEN utl_http.end_of_body THEN
      utl_http.end_response(l_http_response);
  END;

      IF (l_http_response.status_code = 200) THEN
        --------------------------------------------------------------------------
         -- Create XML type from response text
        l_resp_xml := xmltype.createxml(l_clob_response);
        -- Clean SOAP header
        SELECT extract(l_resp_xml, 'Envelope/Body/node()', l_namespace_soap)
          INTO l_resp_xml
          FROM dual;
      
        -- Extract OUTPUT value
        l_result_xml_node := '/GetCitiesByCountryResponse/GetCitiesByCountryResult';
      
        SELECT extractvalue(l_resp_xml,
                            '/GetCitiesByCountryResponse/GetCitiesByCountryResult/NewDataSet/Table/City',
                            'xmlns="http://www.webservicex.net/globalweather.asmx?op=GetCitiesByCountry"')
          INTO l_response_text
          FROM dual;
      
        SELECT count(*) INTO count_ from x_xml_test;
      
        INSERT INTO x_xml_test (ser_no, p_xml) VALUES (count_ + 1, l_resp_xml);
      
      END IF;

    BEGIN
      --------------------------------------------------------------------------
      --- need to replace all tags in the xml with the standard to read it....
      --------------------------------------------------------------------------

    -- xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    --xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
    --xmlns:soap12="http://www.w3.org/2003/05/soap-envelope"
    
    -------------------------------------------------------------------------------
      FOR i in (select *
                  from (select t.p_xml.getclobval() p_xml
                          from X_XML_TEST t
                         ORDER BY t.ser_no desc)
                 where rownum = 1) LOOP
        FOR j IN (SELECT EXTRACTVALUE(column_value,
                                      'GetCitiesByCountryResult') Result
                    FROM TABLE(XMLSequence(XMLTYPE(i.p_xml)
                                           .extract('/GetCitiesByCountryResponse/GetCitiesByCountryResult')))) LOOP
          dbms_output.put_line('Result----->' || j.Result);
        END LOOP;
      END LOOP;
    END;
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

      IF l_http_request.private_hndl IS NOT NULL THEN
        utl_http.end_request(l_http_request);
      END IF;

      IF l_http_response.private_hndl IS NOT NULL THEN
        utl_http.end_response(l_http_response);
      END IF;
      
  COMMIT;

END;
-------------------------------------------------------------------------------------------------

/* RESULT LOOKS LIKE:


Result-----><NewDataSet>
  <Table>
    <Country>Pakistan</Country>
    <City>Dera Ismail Khan</City>
  </Table>
  <Table>
    <Country>Pakistan</Country>
    <City>Jacobabad</City>
  </Table>
  <Table>
    <Country>Pakistan</Country>
    <City>Jiwani</City>
  </Table>
  <Table>
    <Country>Pakistan</Country>
    <City>Karachi Airport</City>
  </Table>
  <Table>
  
  */
