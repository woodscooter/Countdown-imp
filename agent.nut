
// Countdown, with destination select

// Put first-choice, second-choice and more bus stop numbers into this array:
// Recommended limit is 7 bus stops
local Selector = ["57628", "51066", "47140", "58627", "50869","58363", "57660"];


// Push buttons on Imp pins 1, 2 cycle through destinations.

// A list of local bus stops
//const bustop = "47140";	// Test street
//const bustop = "47860";	// Fox & Duck
//const bustop = "57780";	// Mariner Gardens, 371 towards Richmond
//const bustop = "57522";	// Mariner Gardens, 371 towards Kingston
//const bustop = "57628";		// 371 Lock Road to Richmond
//const bustop = "51066";		// 371 Lock Road to Kingston
//const bustop = "58627";	// Ham Street, 371 towards Richmond
//const bustop = "50869";	// Ham Street, 371 towards Kingston
//const bustop = "71738";  // Ham Gate Ave, 65 to Richmond
//const bustop = "58363";	// The Dysart, 371, 65 towards Richmond
//const bustop = "57660";	// Ham Parade, 65 towards Kingston
//const bustop = "47140";	// Richmond Road, 371 towards Kingston


local tflBASE = "http://countdown.tfl.gov.uk/stopBoard/";
local tflURL;

// for fetching bus stop indicator
local indBASE = "http://countdown.api.tfl.gov.uk/interfaces/ura/instant_V1?StopCode1=";
local indTAIL = "&StopAlso=true&ReturnList=StopPointIndicator";
local indURL = "";
local indicator = {
	text = "",
	size = Selector.len()
};

// Selection of one from 7 bus stops (0..6)
local destSelect =0;	// 0 = first choice, 1 = second choice destination, ...

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

// Global timer handles
local busTimer;
local wuTimer;

// To detect when device is off
local heartbeat =0;

function newDestination (dest) {
	if (dest >= Selector.len())
		dest = 0;
	destSelect = dest;
	prevbusInfo=[{string=""},{string=""},{string=""}];
	indURL = "";
	indicator.text = "";
	indicator.size = Selector.len();
 	getBusTimes();
}


function getBusTimes() {

	imp.cancelwakeup(busTimer);		// cancel any previously set timer
	if (heartbeat)	{
		--heartbeat;	// Use up one heartbeat
    	busTimer = imp.wakeup(30, getBusTimes);	// new bus data available every 30s
    }

	// Request the bus data
    server.log(format("Destination: %d", destSelect));
	tflURL = tflBASE + Selector[destSelect] + "/";

    server.log(format("Getting data for stop: %s", Selector[destSelect]));
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

		// check for a Bus Stop Indicator, if necessary
	if (indURL == "") {
		indURL = indBASE + Selector[destSelect] + indTAIL;

    	server.log(format("Sending request: %s", indURL));
    	req = http.get(indURL);
    	res = req.sendsync();
    
    	// check the status code on the response to verify that it's what we actually wanted.
    	if (res.statuscode != 200) {
        	server.log("Request failed.");
     		server.log(format("Response returned with status %d", res.statuscode));
		}
		// Pick the Bus Stop Indicator from the response
		// format is [4,"1.0",1401143349197] [0,"W"]  where W is the indicator, otherwise null
		// it's not valid JSON, try using regex
		local ex = regexp(@",\d+.+,(\p\w+\d?\p)");
		local result = ex.capture(res.body);
		if (result) {
		    indicator.text = res.body.slice(result[1].begin,result[1].end);
		} else {
		    indicator.text = "";
		}
		server.log(format("Indicator is %s", indicator.text));
    	device.send("BusStopInd", indicator);
		
 	}
}       // end getBusTimes()
      

function getConditions() {
	imp.cancelwakeup(wuTimer);		// cancel any previously set timer
	if (heartbeat)	{
		--heartbeat;	// Use up one heartbeat
    	wuTimer = imp.wakeup(900, getConditions);	// every 15 minutes
	}
    
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
    // server.log(format("Obtained forecast for ", weather.display_location.city));
    forecastString += (" "+weather.feelslike_c+"C");


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
    busTimer = imp.wakeup(2, getBusTimes);
    wuTimer = imp.wakeup(3, getConditions);
}

function DeviceUp(dummy) {
    // Just come back to life?
    if (heartbeat==0) {
        Initialise(1);
    }
	// The Device is on, so recharge the heartbeat count
	heartbeat = 4;
}

device.on("reset",Initialise);
device.on("alive",DeviceUp);

device.on("newbus",newDestination);


