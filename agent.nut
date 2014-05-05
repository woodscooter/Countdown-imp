
// Countdown
//const bustop = "47140";	// Test street
//const bustop = "47860";	// Fox & Duck
//const bustop = "57780";	// Mariner Gardens, 371 towards Richmond
//const bustop = "57522";	// Mariner Gardens, 371 towards Kingston
//const bustop = "57628";		// 371 Lock Road to Richmond
//const bustop = "51066";		// 371 Lock Road to Kingston
const bustop = "50869";	// Ham Street, 371 towards Richmond
//const bustop = "47140";	// Ham Street, 371 towards Kingston
//const bustop2 = "71738";  // Ham Gate Ave, 65 to Richmond
//const bustop = "58363";	// The Dysart, 371, 65 towards Richmond
//const bustop = "57660";	// Ham Parade, 65 towards Kingston
//const bustop = "47140";	// Richmond Road, 371 towards Kingston

local tflURL = "http://countdown.tfl.gov.uk/stopBoard/"+bustop+"/";
//local tflURL2 = "http://countdown.tfl.gov.uk/stopBoard/"+bustop2+"/";

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
// local myAPIKey = "b7406fdedec26d9a"; // Paul's 
local myAPIKey = "7cefcf88b62b9f0b";    // Ian's
local wunderBaseURL = "http://api.wunderground.com/api/"+myAPIKey+"/";

// Add the zip code you want to get the forecast for here.
local zip = "locid:UKXX9192";

// The wunderground API has a lot of different features (tides, sailing, etc)
// We use "conditions" to indicate we just want a general weather report
local reportType = "conditions";

// Global store of the three lines being displayed by the imp screen
local prevbusInfo=[{string=""},{string=""},{string=""}];

function getBusTimes() {
    imp.wakeup(31, getBusTimes);	// new bus data available every 30s
    
	// Request the bus data
    server.log(format("Getting data for stop: %s", bustop));
    // server.log(format("Sending request to %s", tflURL));
    local req = http.get(tflURL);
    local res = req.sendsync();
    
    // check the status code on the response to verify that it's what we actually wanted.
    if (res.statuscode != 200) {
        server.log("Request failed.");
     	server.log(format("Response returned with status %d", res.statuscode));
       return;
        }
        
    // log the body of the message and find out what we got.
    // server.log(res.body);
    
    // hand off data to be parsed
    local response = http.jsondecode(res.body);
    local bus = response.arrivals;
    local i =0;
    local busString = "";
    local busInfo = [{string=""},{string=""},{string=""}];
    
    // format and prepare up to three lines
      if (0 in bus) {
        while (i in bus) {
          busString = (bus[i].estimatedWait +" ");
          busString += (bus[i].routeName +" ");
          busString += (bus[i].destination);
          busString += ("                    ");  // trailing spaces
          busInfo[i].string <- busString.slice(0,20); 	// chop it down to 20 chars
          busInfo[i].line <- i+1;
		  i++;
          // only display 3 results
          if (i==3) break;
        } // end while
        // in case we didn't get three lines...
        while (i<3) {
            busInfo[i].string <- ("                    ");
            busInfo[i].line <- i+1;
            i++;
        }
      }
      else {
           // Got no arrival data
            busInfo[0].string <- "No bus expected";
            busInfo[0].line <- 1;
            busInfo[1].string <- ("                    ");
            busInfo[1].line <- 2;
            busInfo[2].string <- ("                    ");
            busInfo[2].line <- 3;
      }
      // compare each line with current display
      for (local i=0;i<3;i++)   {
        if (prevbusInfo[i].string == busInfo[i].string)
            busInfo[i].display <- 0; // same, don't re-display it
        else {
            busInfo[i].display <- 1; // display new/changed data
            prevbusInfo[i].string = busInfo[i].string;
        }
      }
      
      // send selected lines to imp for display
      for (local i=0;i<3;i++)   {
        if (busInfo[i].display) {
            server.log(format("Sending line %d to imp: %s",busInfo[i].line,busInfo[i].string));
            device.send("busData",busInfo[i]);
        }
      }
}       // end getBusTimes()
      

function getConditions() {
    imp.wakeup(900, getConditions);	// every 15 minutes
    
//    server.log(format("Agent getting current conditions for %s", zip));
    // register the next run of this function, so we'll check again in five minutes
    
    // cat some strings together to build our request URL
    local reqURL = wunderBaseURL+reportType+"/q/"+zip+".json";

    // call http.get on our new URL to get an HttpRequest object. Note: we're not using any headers
//    server.log(format("Sending request to %s", reqURL));
    local req = http.get(reqURL);

    // send the request synchronously (blocking). Returns an HttpMessage object.
    local res = req.sendsync();

    // check the status code on the response to verify that it's what we actually wanted.
    if (res.statuscode != 200) {
        server.log("Request for weather data failed.");
    	server.log(format("Response returned with status %d", res.statuscode));
        return;
    }

    // log the body of the message and find out what we got.
    //server.log(res.body);

    // hand off data to be parsed
    local response = http.jsondecode(res.body);
    local weather = response.current_observation;
    local forecastString = "";
    
    // Chunk together our forecast into a printable string
    server.log(format("Obtained forecast for ", weather.display_location.city));
    forecastString += ("Temp "+weather.feelslike_c+"C");


    // relay the formatting string to the device
    // it will then be handled with function registered with "agent.on":
    // agent.on("newData", function(data) {...});
    server.log(format("Sending temperature to imp: %s",forecastString));
    device.send("weather", forecastString);
    
}

function Initialise(dummy) {

	// allow 2-3 seconds for LCD to settle
	// then get initial screen displays
	prevbusInfo=[{string=""},{string=""},{string=""}];
    imp.wakeup(2, getBusTimes);
    imp.wakeup(3, getConditions);
}

device.on("reset",Initialise);



