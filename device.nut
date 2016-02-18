
local blankString = "                    "; // String to blank a line.
local buttonSelect = 0; //	Selection of destination
local numberStops = 3;	// Length of Selector array in agent

// Timer handle
local clockTimer;

class LowLevelLcd {
    i2cPort = null;
    lcdAddress = null;

    // commands
    static LCD_CLEARDISPLAY = 0x01;
    static LCD_RETURNHOME = 0x02;
    static LCD_ENTRYMODESET = 0x04;
    static LCD_DISPLAYCONTROL = 0x08;
    static LCD_CURSORSHIFT = 0x10;
    static LCD_FUNCTIONSET = 0x20;
    static LCD_SETCGRAMADDR = 0x40;
    static LCD_SETDDRAMADDR = 0x80;

    // flags for display entry mode
    static LCD_ENTRYRIGHT = 0x00;
    static LCD_ENTRYLEFT = 0x02;
    static LCD_ENTRYSHIFTINCREMENT = 0x01;
    static LCD_ENTRYSHIFTDECREMENT = 0x00;

    // flags for display on/off control
    static LCD_DISPLAYON = 0x04;
    static LCD_DISPLAYOFF = 0x00;
    static LCD_CURSORON = 0x02;
    static LCD_CURSOROFF = 0x00;
    static LCD_BLINKON = 0x01;
    static LCD_BLINKOFF = 0x00;

    // flags for display/cursor shift
    static LCD_DISPLAYMOVE = 0x08;
    static LCD_CURSORMOVE = 0x00;
    static LCD_MOVERIGHT = 0x04;
    static LCD_MOVELEFT = 0x00;

    // flags for function set
    static LCD_8BITMODE = 0x10;
    static LCD_4BITMODE = 0x00;
    static LCD_2LINE = 0x08;
    static LCD_1LINE = 0x00;
    static LCD_5x10DOTS = 0x04;
    static LCD_5x8DOTS = 0x00;

    static PIN_RS = 0x1; // off=command, on=data
    static PIN_RW = 0x2; // off=write, on=read
    static PIN_EN = 0x4; // clock
    static PIN_LED = 0x8;

    /*
     * Construct a new ImpLcd instance to talk with a generic I2C controlled LCD
     *
     * @port - I2C object. One of the hardware.i2c* objects
     * @address - integer, base address of the I2C LCD
     */
    constructor(port, address)
    {
        this.i2cPort = port;
        this.lcdAddress = address;

        this.i2cPort.configure(CLOCK_SPEED_10_KHZ);

        // set LCD to 8 bits mode 3 times
        for (local i=0; i<3; i++)
        {
            this.sendPulse(0x03 << 4, 0);
        }

        // set LCD to 4 bits mode
        this.sendPulse(0x02 << 4, 0);
    }

    /*
     * Read `length` bytes from the I2C read address
     *
     * @length - integer, number of bytes to read
     */
    function rawRead(length)
    {
        return this.i2cPort.read((this.lcdAddress << 1) | 0x1, length);
    }

    /*
     * I2C write wrapper. Write `data` to the I2C write address
     *
     * @data - string, data to send
     */
    function rawWrite(data)
    {
        return this.i2cPort.write((this.lcdAddress << 1) | 0x0, data);
    }

    /*
     * Wrapper around rawWrite() that accepts a byte instead of a string. It also keeps the LED on all time
     *
     * @byte - byte, byte to send
     */
    function rawWriteByte(byte)
    {
        return this.rawWrite(format("%c", byte | PIN_LED));
    }

    /*
     * Write a string to the display on the current position
     *
     * @s - string, string to print
     */
    function writeString(s)
    {
        for (local i=0; i<s.len(); i++)
        {
            this.send(s[i], PIN_RS);
        }
    }

    /*
     * Send a command to the LCD
     *
     * @value - byte, command to send
     */
    function sendCommand(value)
    {
        this.send(value, 0);
    }

    /*
     * Pulse a value to the LCD
     */
    function sendPulse(value, mode)
    {
        mode = mode | PIN_LED;

        this.rawWriteByte(value | mode);
        this.rawWriteByte(value | mode | PIN_EN);
        imp.sleep(0.0006);
        this.rawWriteByte(value | mode);
    }

    /*
     * Push an 8bit value to the LCD with two 4bit pulses
     */
    function send(value, mode)
    {
        local highNib = value & 0xf0;
        local lowNib = (value << 4) & 0xf0;

        this.sendPulse(highNib, mode);
        this.sendPulse(lowNib, mode);
    }
}

class ImpLcd
{
    _lcd = null;
    _functionSet = LowLevelLcd.LCD_4BITMODE | LowLevelLcd.LCD_1LINE | LowLevelLcd.LCD_5x8DOTS;
    _displayControl = LowLevelLcd.LCD_DISPLAYON | LowLevelLcd.LCD_CURSOROFF | LowLevelLcd.LCD_BLINKOFF;

    /*
     * Construct a new ImpLcd instance to talk with a generic I2C controlled LCD
     *
     * @port - I2C object. One of the hardware.i2c* objects
     * @address - integer, base address of the I2C LCD
     * @rows - integer, number of rows on the LCD
     * @dotSize - integer, when this value is greater than zero, the LCD is configured to display 5x10 dots characters. Otherwise, 5x8 dots characters.
     */
    constructor(port, address, rows, dotSize)
    {
        this._lcd = LowLevelLcd(port, address);

        if (rows > 1)
        {
            this._functionSet = this._functionSet | LowLevelLcd.LCD_2LINE;
        }

        if (dotSize > 0)
        {
            this._functionSet = this._functionSet | LowLevelLcd.LCD_5x10DOTS;
        }

        this.functionSet();
        this.displayControl();
        this.clear();
    }

    /*
     * Send the current value of _functionSet to the LCD
     */
    function functionSet()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_FUNCTIONSET | this._functionSet);
    }

    /*
     * Send the current value of _displayControl to the LCD
     */
    function displayControl()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_DISPLAYCONTROL | this._displayControl);
    }

    /*
     * Write a string to the display on the current position
     *
     * @s - string, string to print
     */
    function writeString(s)
    {
        return this._lcd.writeString(s);
    }

    /*
     * Set the LCD cursor to given position
     *
     * @col - integer, column number, zero based
     * @row - integer, row number, zero based
     */
    function setCursor(col, row)
    {
        local rowOffsets = [ 0x00, 0x40, 0x14, 0x54 ];
        return this._lcd.sendCommand(LowLevelLcd.LCD_SETDDRAMADDR | (col + rowOffsets[row]));
    }

    /*
     * Clear the LCD
     */
    function clear()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_CLEARDISPLAY);
    }

    /*
     * Turn display off (doesn't turn off the LED)
     */
    function noDisplay()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_DISPLAYON;
        return this.displayControl();
    }

    /*
     * Turn display on
     */
    function display()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_DISPLAYON;
        return this.displayControl();
    }

    /*
     * Turn cursor blinking off
     */
    function noBlink()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_BLINKON;
        return this.displayControl();
    }

    /*
     * Turn cursor blinking on
     */
    function blink()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_BLINKON;
        return this.displayControl();
    }

    /*
     * Turn off the cursor
     */
    function noCursor()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_CURSORON;
        return this.displayControl();
    }

    /*
     * Turn the cursor on
     */
    function cursor()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_CURSORON;
        return this.displayControl();
    }
}



// create an ImpLcd instance. Our LCD is connected to I2C on ports 8,9 with a base address of 0x27
lcd <- ImpLcd(hardware.i2c89, 0x27, 2, 0);


function newDataHandeler(busInfo)
    {
        // update the display screen with the new data
        if (busInfo.string.len() == 0 ) {
          lcd.setCursor(0, busInfo.line);
          lcd.writeString(blankString);
        	}
        	else {
        		server.log(busInfo.string)
        		lcd.setCursor(0, busInfo.line);
        		lcd.writeString(busInfo.string);
         }
    }

function indicatorHandeler(indicator)
    {
 		numberStops = indicator.size;
  		lcd.setCursor(12, 0);
   		lcd.writeString("        ");
		if (indicator.text.len() > 0) {
   			lcd.setCursor(12, 0);
   			lcd.writeString("Stop"+indicator.text);
		}
	}

function weatherHandeler(forecastString)
    {
        // update the display screen with the new data
        server.log(forecastString);
        lcd.setCursor(5, 0);
        lcd.writeString("      ");
        lcd.setCursor(5, 0);
        lcd.writeString(forecastString);
    }

// Number of days from start of year to UTC/BST change day
function last_sunday_in_march(t)
{
local days, sunday;
	days = 89;			// Days from 1st Jan to end of march, less 1 'cos we count from 0
	if (t.year%4 ==0)		// Add a day if this is a leap year
		++days;
	sunday = t.year;
	sunday *= 5;        // Find a position in the week for sunday
	sunday /= 4;
	sunday += 4;
	days -= sunday%7;
	return (days);
}

function last_sunday_in_october(t)
{
local days, sunday;
	days = 303;					// Days from 1st Jan to end of october, less 1 'cos we count from 0
	if (t.year%4 ==0)		// Add a day if this is a leap year
		++days;
	sunday = t.year;
	sunday *= 5;
	sunday /= 4;
	sunday += 1;
	days -= sunday%7;
	return (days);
}

// Returns 1 if the clock should show summer time.

function bst_adjust (t)
{
local march, october;
	march = last_sunday_in_march(t);
	october = last_sunday_in_october(t);
	if ((t.yday > march)
		&& (t.yday < october))
			return 1;
	if ((t.yday == march)
		&& (t.min >= 60))
			return 1;
	if ((t.yday == october)
		&& (t.min < 60))
			return 1;
	return 0;
}

function updateClock()
{
    // update the clock again in 1 second
//	imp.cancelwakeup(clockTimer);		// cancel any previously set timer
//    clockTimer = imp.wakeup(1, updateClock);
    imp.wakeup(1, updateClock);

    local t = date();
    local hour = t.hour+bst_adjust(t);
    if (hour>23) hour = 0;

    // move to the first row, first column
    lcd.setCursor(0, 0);
//    lcd.writeString(format("%02d:%02d:%02d", hour, t.min, t.sec));
	if (t.sec & 1)	{
    	lcd.writeString(format("%02d %02d", hour, t.min));
	} else 	{
    	lcd.writeString(format("%02d:%02d", hour, t.min));
	}

	// notify the Agent that we are still alive
	agent.send("alive",0);
}


if (hardware.wakereason() == WAKEREASON_POWER_ON || hardware.wakereason() == WAKEREASON_NEW_SQUIRREL) 
    {
        server.log("imp booting")
        lcd.clear();
        agent.send("reset",0);
    }

agent.on("weather",weatherHandeler);    
agent.on("busData",newDataHandeler);
agent.on("BusStopInd",indicatorHandeler);

// Debounce controls
local ctlUp = {
	count = 0,
	state = 0,
	seen = 0
}

local ctlDown = {
	count = 0,
	state = 0,
	seen = 0
}

function buttonUpcheck()	{
	if (hardware.pin1.read())	{
			// button not pressed
			if (--ctlUp.count <= 0)	{
				ctlUp.state = 0;
				ctlUp.count = 0;
//	server.log("buttonUp released");
			} else {
				imp.wakeup(0.010, buttonUpcheck);
			}
	}	else	{
			// button is pressed
			if (++ctlUp.count >= 8)	{
				if (ctlUp.state != 1)	{
					ctlUp.state = 1;
					ctlUp.count = 8;
	server.log("buttonUp pressed");
					// Move up the list of stops
					++buttonSelect;
					// Wrap at the low and high ends
					if (buttonSelect < 0) { buttonSelect = numberStops-1; }
					if (buttonSelect >= numberStops) { buttonSelect = 0; }
	server.log("buttonSelect: " + buttonSelect);
					agent.send("newbus",buttonSelect);
				}
			} else {
				imp.wakeup(0.010, buttonUpcheck);
			}
	}
}

function buttonDowncheck()	{
	if (hardware.pin2.read())	{
			// button not pressed
			if (--ctlDown.count <= 0)	{
				ctlDown.state = 0;
				ctlDown.count = 0;
//	server.log("buttonDown released");
			} else {
				imp.wakeup(0.010, buttonDowncheck);
			}
	}	else	{
			// button is pressed
			if (++ctlDown.count >= 8)	{
				if (ctlDown.state != 1)	{
					ctlDown.state = 1;
					ctlDown.count = 8;
	server.log("buttonDown pressed");
					// Move down the list of stops
					--buttonSelect;
					// Wrap at the low and high ends
					if (buttonSelect < 0) { buttonSelect = numberStops-1; }
					if (buttonSelect >= numberStops) { buttonSelect = 0; }
	server.log("buttonSelect: " + buttonSelect);
					agent.send("newbus",buttonSelect);
				}
			} else {
				imp.wakeup(0.010, buttonDowncheck);
			}
	}
}


hardware.pin1.configure(DIGITAL_IN_PULLUP,buttonUpcheck);
hardware.pin2.configure(DIGITAL_IN_PULLUP,buttonDowncheck);

//Create a zero-volt source at pin 5
ground <- hardware.pin5;
ground.configure(DIGITAL_OUT);
ground.write(0);

// fire updateClock() for the first time
updateClock(); 


/*

// Push button with debounce
class Button {
	state = null;
	count = null;
	sample = null;
	direction = null;

	constructor(conn,updown)
	{
		sample = conn;
//		sample.configure(DIGITAL_IN_PULLUP);
		direction = updown;
		state = 0;
		count = 0;
	}

	function check ()	{
		if (this.sample.read())	{
			// button not pressed
			if (--this.count == 0)	{
				this.state = 0;
				this.count = 0;
	server.log("button released");
			} else {
				imp.wakeup(0.010, this.check);
			}
			
		} else {
			// button is pressed
			if (++this.count >= 4)	{
				this.state = 1;
				this.count = 4;
	server.log("button pressed");
			// Move up or down the list of stops
			++buttonSelect;
			// Wrap at the low and high ends
		if (buttonSelect < 0) { buttonSelect = numberStops; }
		if (buttonSelect >= numberStops) { buttonSelect = 0; }
	server.log("buttonSelect: " + buttonSelect);
		agent.send("newbus",buttonSelect);
			} else {
				imp.wakeup(0.010, this.check);
			}
		}
	}	// end function


} // end class

// Instantiate two instances of the class
local button1 = Button(hardware.pin1, 1);	// increase
local button2 = Button(hardware.pin2, -1);	// decrease
button1.configure(DIGITAL_IN_PULLUP,button1.check);
button2.configure(DIGITAL_IN_PULLUP,button2.check);

//Create a zero-volt source at pin 5
ground <- hardware.pin5;
ground.configure(DIGITAL_OUT);
ground.write(0);

// fire updateClock() for the first time
updateClock(); 

*/
