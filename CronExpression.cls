/*
 * All content copyright Terracotta, Inc., unless otherwise indicated. All rights reserved.
 * 
 * Licensed under the Apache License, Version 2.0 (the 'License'); you may not 
 * use this file except in compliance with the License. You may obtain a copy 
 * of the License at 
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0 
 *   
 * Unless required by applicable law or agreed to in writing, software 
 * distributed under the License is distributed on an 'AS IS' BASIS, WITHOUT 
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
 * License for the specific language governing permissions and limitations 
 * under the License.
 * 
 */

/**
 * Provides a parser and evaluator for unix-like cron expressions. Cron 
 * expressions provide the ability to specify complex time combinations such as
 * 		'At 8:00am every Monday through Friday' 
 * or	'At 1:30am every last Friday of the month'. 
 * 
 * Cron expressions are comprised of 6 required fields and one optional field
 * separated by white space. The fields respectively are described as follows:
 *
 * FIELD NAME			ALLOWED VALUES			ALLOWED SPECIAL CHARACTERS
 * Seconds				0-59					
 * Minutes				0-59
 * Hours				0-23					, - * /		
 * Day-of-Month			1-31					, - * ? / L W
 * Month				1-12 or JAN-DEC			, - * /
 * Day-of-Week			1-7 or SUN-SAT			, - * ? / L #
 * Year (Optional)		empty, 1970-2199		, - * /
 *
 * EXPLANATION OF SPECIAL CHARACTERS:
 *
 * The '*' character is used to specify all values. For example, '*' 
 * in the minute field means 'every minute'
 *
 * The '?' character is allowed for the day-of-month and day-of-week fields. It
 * is used to specify 'no specific value'. This is useful when you need to
 * specify something in one of the two fields, but not the other.
 *
 * The '-' character is used to specify ranges For example '10-12' in
 * the hour field means 'the hours 10, 11 and 12'.
 * 
 * The ',' character is used to specify additional values. For example
 * 'MON,WED,FRI' in the day-of-week field means 
 * 'the days Monday, Wednesday, and Friday'.
 * 
 * The '/' character is used to specify increments. For example '0/15'
 * in the seconds field means 'the seconds 0, 15, 30, and 45'. And 
 * '5/15' in the seconds field means 'the seconds 5, 20, 35, and 50'.
 * Specifying '*' before the  '/' is equivalent to specifying 0 is
 * the value to start with. Essentially, for each field in the expression, there
 * is a set of numbers that can be turned on or off. For seconds and minutes, 
 * the numbers range from 0 to 59. For hours 0 to 23, for days of the month 0 to
 * 31, and for months 1 to 12. The '/' character simply helps you turn
 * on every 'nth' value in the given set. Thus '7/6' in the
 * month field only turns on month '7', it does NOT mean every 6th 
 * month, please note that subtlety.  
 * 
 * The 'L' character is allowed for the day-of-month and day-of-week fields.
 * This character is short-hand for 'last', but it has different 
 * meaning in each of the two fields. For example, the value 'L' in 
 * the day-of-month field means 'the last day of the month' - day 31 
 * for January, day 28 for February on non-leap years. If used in the 
 * day-of-week field by itself, it simply means '7' or 
 * 'SAT'. But if used in the day-of-week field after another value, it
 * means 'the last xxx day of the month' - for example '6L'
 * means 'the last friday of the month'. You can also specify an offset 
 * from the last day of the month, such as 'L-3' which would mean the third-to-last 
 * day of the calendar month. When using the 'L' option, it is important not to 
 * specify lists, or ranges of values, as you'll get confusing/unexpected results.
 * 
 * The 'W' character is allowed for the day-of-month field.  This character 
 * is used to specify the weekday (Monday-Friday) nearest the given day.  
 * As an example, if you were to specify '15W' as the value for the 
 * day-of-month field, the meaning is: 'the nearest weekday to the 15th of
 * the month'. So if the 15th is a Saturday, the trigger will fire on 
 * Friday the 14th. If the 15th is a Sunday, the trigger will fire on Monday the
 * 16th. If the 15th is a Tuesday, then it will fire on Tuesday the 15th. 
 * However if you specify '1W' as the value for day-of-month, and the
 * 1st is a Saturday, the trigger will fire on Monday the 3rd, as it will not 
 * 'jump' over the boundary of a month's days.  The 'W' character can only be 
 * specified when the day-of-month is a single day, not a range or list of days.
 * 
 * The 'L' and 'W' characters can also be combined for the day-of-month 
 * expression to yield 'LW', which translates to 'last weekday of the 
 * month'.
 * 
 * The '#' character is allowed for the day-of-week field. This character is
 * used to specify 'the nth' XXX day of the month. For example, the 
 * value of '6#3' in the day-of-week field means the third Friday of 
 * the month (day 6 = Friday and '#3' = the 3rd one in the month). 
 * Other examples: '2#1' = the first Monday of the month and 
 * '4#5' = the fifth Wednesday of the month. Note that if you specify
 * '#5' and there is not 5 of the given day-of-week in the month, then
 * no firing will occur that month.  If the '#' character is used, there can
 * only be one expression in the day-of-week field ('3#1,6#3' is 
 * not valid, since there are two expressions).
 * 
 * <!--The 'C' character is allowed for the day-of-month and day-of-week fields.
 * This character is short-hand for 'calendar'. This means values are
 * calculated against the associated calendar, if any. If no calendar is
 * associated, then it is equivalent to having an all-inclusive calendar. A
 * value of '5C' in the day-of-month field means 'the first day included by the
 * calendar on or after the 5th'. A value of '1C' in the day-of-week field
 * means 'the first day included by the calendar on or after Sunday'.-->
 * 
 * The legal characters and the names of months and days of the week are not
 * case sensitive.
 * 
 * NOTES:
 * 
 * Support for specifying both a day-of-week and a day-of-month value is
 * not complete (you'll need to use the '?' character in one of these fields).
 * 
 * Overflowing ranges is supported - that is, having a larger number on 
 * the left hand side than the right. You might do 22-2 to catch 10 o'clock 
 * at night until 2 o'clock in the morning, or you might have NOV-FEB. It is 
 * very important to note that overuse of overflowing ranges creates ranges 
 * that don't make sense and no effort has been made to determine which 
 * Integererpretation CronExpression chooses. An example would be 
 * '0 0 14-6 ? * FRI-MON'. 
 * 
 * Original org.quartz.CronExpression code Authorship:
 * -------------------------------------------
 * @author Sharada Jambula, James House
 * @author Contributions from Mads Henderson
 * @author Refactoring from CronTrigger to CronExpression by Aaron Craven
 *
 * APEX Implementation authorship:
 * @author Zach McElrath (zachelrath)
 */
 
public virtual class CronExpression {
    
    public static final Integer SECOND = 0;
    public static final Integer MINUTE = 1;
    public static final Integer HOUR = 2;
    public static final Integer DAY_OF_MONTH = 3;
    public static final Integer MONTH = 4;
    public static final Integer DAY_OF_WEEK = 5;
    public static final Integer YEAR = 6;
    public static final Integer ALL_SPEC_INT = 99; // '*'
    public static final Integer NO_SPEC_INT = 98; // '?'
    public static final Integer ALL_SPEC = Integer.valueOf(ALL_SPEC_INT);
    public static final Integer NO_SPEC = Integer.valueOf(NO_SPEC_INT);
    
    public static final Map<String, Integer> monthMap = new Map<String, Integer>{
    	'JAN' => 0,
        'FEB' => 1,
        'MAR' => 2,
        'APR' => 3,
        'MAY' => 4,
        'JUN' => 5,
        'JUL' => 6,
        'AUG' => 7,
        'SEP' => 8,
        'OCT' => 9,
        'NOV' => 10,
        'DEC' => 11
    };
    public static final Map<String, Integer> dayMap = new Map<String, Integer>{
        'SUN' => 1,
        'MON' => 2,
        'TUE' => 3,
        'WED' => 4,
        'THU' => 5,
        'FRI' => 6,
        'SAT' => 7
    };
    private String cronExpression = null;
    // the difference (in minutes) between the current time in the current locale
    // and the current time in GMT/UTC
    private Integer timeZoneOffsetMinutes = null;
    protected transient SortedSet seconds;
    protected transient SortedSet minutes;
    protected transient SortedSet hours;
    protected transient SortedSet daysOfMonth;
    protected transient SortedSet months;
    protected transient SortedSet daysOfWeek;
    protected transient SortedSet years;

    protected transient boolean lastdayOfWeek = false;
    protected transient Integer nthdayOfWeek = 0;
    protected transient boolean lastdayOfMonth = false;
    protected transient boolean nearestWeekday = false;
    protected transient Integer lastdayOffset = 0;
    protected transient boolean expressionParsed = false;
    
    public static final Integer MAX_YEAR = 2199;

	public class CronException extends Exception {}

    /**
     * Constructs a new CronExpression based on the specified 
     * parameter.
     * 
     * @param cronExpression String representation of the cron expression the
     *                       new object should represent
     * @throws CronException
     *         if the string expression cannot be parsed into a valid CronExpression
     */
    public CronExpression(String cronExpression) {
        if (cronExpression == null) {
            throw new CronException('cronExpression cannot be null');
        }
        
        //this.cronExpression = cronExpression.toUpperCase(Locale.US);
        this.cronExpression = cronExpression.toUpperCase();
        
        buildExpression(this.cronExpression);
    }
    
    /**
     * Indicates whether the given date satisfies the cron expression. Note that
     * milliseconds are ignored, so two Dates falling on different milliseconds
     * of the same second will always have the same result here.
     * 
     * @param date the date to evaluate
     * @return a boolean indicating whether the given date satisfies the cron
     *         expression
     */
    public boolean isSatisfiedBy(Date d) {
    	/*
        Calendar testDateCal = Calendar.getInstance(getTimeZone());
        testDateCal.setTime(d);
        testDateCal.set(Calendar.MILLISECOND, 0);
        Date originalDate = testDateCal.getTime();
        
        testDateCal.add(Calendar.SECOND, -1);
        
        Date timeAfter = getTimeAfter(testDateCal.getTime());

        return ((timeAfter != null) && (timeAfter.equals(originalDate)));
        */
        // TODO
        return null;
    }
    
    /**
     * Returns the next date/time after the given date/time which
     * satisfies the cron expression.
     * 
     * @param date the date/time at which to begin the search for the next valid
     *             date/time
     * @return the next valid date/time
     */
    /* 
    public Date getNextValidTimeAfter(Date d) {
        return getTimeAfter(d);
    }
    */
    //public Datetime getNextValidTimeAfter(Datetime dt) {
     //   return getTimeAfter(dt);
    //}
    
    /**
     * Returns the next date/time <I>after</I> the given date/time which does
     * <I>not</I> satisfy the expression.
     *
     * All calculations are done in GMT/UTC.
     * 
     * @param date the date/time at which to begin the search for the next 
     *             invalid date/time
     * @return the next valid date/time
     */
     /*
    public Date getNextInvalidTimeAfter(Date d) {
        long difference = 1000;
        
        //move back to the nearest second so differences will be accurate
        Calendar adjustCal = Calendar.getInstance(getTimeZone());
        adjustCal.setTime(d);
        adjustCal.set(Calendar.MILLISECOND, 0);
        Date lastDate = adjustCal.getTime();
        
        Date newDate = null;
        
        //TODO: (QUARTZ-481) IMPROVE THIS! The following is a BAD solution to this problem. Performance will be very bad here, depending on the cron expression. It is, however A solution.
        
        //keep getting the next included time until it's farther than one second
        // apart. At that poInteger, lastDate is the last valid fire time. We return
        // the second immediately following it.
        while (difference == 1000) {
            newDate = getTimeAfter(lastDate);
            if(newDate == null)
                break;
            
            difference = newDate.getTime() - lastDate.getTime();
            
            if (difference == 1000) {
                lastDate = newDate;
            }
        }
        
        return new Date(lastDate.getTime() + 1000);
    }
    */
    
    /**
     * Returns the number of minutes off of GMT of the current User's TimeZone
     */
    public Integer getTimezoneOffsetMinutes() {
        if (timeZoneOffsetMinutes == null) {
            timeZoneOffsetMinutes = TimeConversions.GetCurrentUserTZOffsetFromGMT();
        }
        return timeZoneOffsetMinutes;
    }
    
    /**
     * Returns the string representation of the CronExpression
     * 
     * @return a string representation of the CronExpression
     */
    public String asString() {
        return cronExpression;
    }

    /**
     * Indicates whether the specified cron expression can be parsed Integero a 
     * valid cron expression
     * 
     * @param cronExpression the expression to evaluate
     * @return a boolean indicating whether the given expression is a valid cron
     *         expression
     */
    public static boolean isValidExpression(String cronExpression) {
        
        try {
            new CronExpression(cronExpression);
        } catch (CronException pe) {
            return false;
        }
        
        return true;
    }

    public static void validateExpression(String cronExpression) {
        new CronExpression(cronExpression);
    }
    
    
    ////////////////////////////////////////////////////////////////////////////
    //
    // Expression Parsing Functions
    //
    ////////////////////////////////////////////////////////////////////////////

    protected void buildExpression(String expression) {
        expressionParsed = true;

        try {

			/*
            if (seconds == null) seconds = new Set<Integer>();
            if (minutes == null) minutes = new Set<Integer>();
            if (hours == null) hours = new Set<Integer>();
            if (daysOfMonth == null) daysOfMonth = new Set<Integer>();
            if (months == null) months = new Set<Integer>();
            if (daysOfWeek == null) daysOfWeek = new Set<Integer>();
            if (years == null) years = new Set<Integer>();
            */
            
            if (seconds == null) seconds = new SortedSet();
            if (minutes == null) minutes = new SortedSet();
            if (hours == null) hours = new SortedSet();
            if (daysOfMonth == null) daysOfMonth = new SortedSet();
            if (months == null) months = new SortedSet();
            if (daysOfWeek == null) daysOfWeek = new SortedSet();
            if (years == null) years = new SortedSet();

            Integer tokenOn = SECOND;

            List<String> tokens = expression.split(' ');
            Iterator<String> tokenizer = tokens.iterator();

            while (tokenizer.hasNext() && tokenOn <= YEAR) {
            	// Get the next token
                String token = tokenizer.next().trim();

                // throw an exception if L is used with other days of the month
                if(tokenOn == DAY_OF_MONTH && token.indexOf('L') != -1 && token.length() > 1 && token.indexOf(',') >= 0) {
                    throw new CronException('Support for specifying \'L\' and \'LW\' with other days of the month is not implemented');
                }
                // throw an exception if L is used with other days of the week
                if(tokenOn == DAY_OF_WEEK && token.indexOf('L') != -1 && token.length() > 1  && token.indexOf(',') >= 0) {
                    throw new CronException('Support for specifying \'L\' with other days of the week is not implemented');
                }
                if(tokenOn == DAY_OF_WEEK && token.indexOf('#') != -1 && token.indexOf('#', token.indexOf('#') +1) != -1) {
                    throw new CronException('Support for specifying multiple \'nth\' days is not imlemented.');
                }
                
                // If the current token contains a comma,
                // we'll need to split it up into smaller tokens and parse them as well
                List<String> valueTokens = token.split(',');
                Iterator<String> valueTokenizer = valueTokens.iterator();
                while (valueTokenizer.hasNext()) {
                    String v = valueTokenizer.next();
                    storeExpressionVals(0, v, tokenOn);
                }

				// Move on to the next token
                tokenOn++;
            }

            if (tokenOn <= DAY_OF_WEEK) throw new CronException('Unexpected end of expression. Expression Length: ' + expression.length());

            if (tokenOn <= YEAR) storeExpressionVals(0, '*', YEAR);

            //Set<Integer> dow = getSet(DAY_OF_WEEK);
            SortedSet dow = getSet(DAY_OF_WEEK);
            //Set<Integer> dom = getSet(DAY_OF_MONTH);
            SortedSet dom = getSet(DAY_OF_MONTH);

            // Copying the logic from the UnsupportedOperationException below
            boolean dayOfMSpec = !dom.contains(NO_SPEC);
            boolean dayOfWSpec = !dow.contains(NO_SPEC);

            if (dayOfMSpec && !dayOfWSpec) { 
                // skip
            } else if (dayOfWSpec && !dayOfMSpec) { 
                // skip
            } else {
                throw new CronException('Support for specifying both a day-of-week AND a day-of-month parameter is not implemented.');
            }
        } catch (CronException ce) {
            throw ce;
        } catch (Exception e) {
            throw new CronException('Illegal cron expression format (' + e.getMessage() + ')');
        }
    }

    protected Integer storeExpressionVals(Integer pos, String s, Integer type) {

        Integer incr = 0;
        Integer i = skipWhiteSpace(pos, s);
        if (i >= s.length()) {
            return i;
        }
        String c = CharAt(s,i);
        
        // Define a Pattern that we want to match our String against
		Pattern p = Pattern.compile('^L-[0-9]*[W]?');
        
        if ((c >= 'A') && (c <= 'Z') && (!s.equals('L')) && (!s.equals('LW')) && (!(p.matcher(s)).matches())) {
            String sub = s.substring(i, i + 3);
            Integer sval = -1;
            Integer eval = -1;
            if (type == MONTH) {
                sval = getMonthNumber(sub) + 1;
                if (sval <= 0) {
                    throw new CronException('Invalid Month value: \'' + sub + '\'');
                }
                if (s.length() > i + 3) {
                    c = CharAt(s,i+3);
                    if (c == '-') {
                        i += 4;
                        sub = s.substring(i, i + 3);
                        eval = getMonthNumber(sub) + 1;
                        if (eval <= 0) {
                            throw new CronException('Invalid Month value: \'' + sub + '\'');
                        }
                    }
                }
            } else if (type == DAY_OF_WEEK) {
                sval = getDayOfWeekNumber(sub);
                if (sval < 0) {
                	throw new CronException('Invalid Day-of-Week value: \'' + sub + '\'');
                }	
                if (s.length() > i + 3) {
                    c = CharAt(s,i+3);
                    if (c == '-') {
                        i += 4;
                        sub = s.substring(i, i + 3);
                        eval = getDayOfWeekNumber(sub);
                        if (eval < 0) throw new CronException('Invalid Day-of-Week value: \'' + sub + '\'');
                    } else if (c == '#') {
                        i += 4;
                        nthdayOfWeek = Integer.valueOf(s.substring(i));
                        if (nthdayOfWeek < 1 || nthdayOfWeek > 5) {
                        	throw new CronException('A numeric value between 1 and 5 must follow the \'#\' option');
                        }
                    } else if (c == 'L') {
                        lastdayOfWeek = true;
                        i++;
                    }
                }

            } else throw new CronException('Illegal characters for this position: \'' + sub + '\'');
            if (eval != -1) {
            	incr = 1;
            }	
            addToSet(sval, eval, incr, type);
            return (i + 3);
        }

        if (c == '?') {
            i++;
            if ((i + 1) < s.length() 
                    && (CharAt(s,i) != ' ' && CharAt(s,i+1) != '\t')) {
                throw new CronException('Illegal character after \'?\': ' + CharAt(s,i));
            }
            if (type != DAY_OF_WEEK && type != DAY_OF_MONTH) {
                throw new CronException('\'?\' can only be specfied for Day-of-Month or Day-of-Week');
            }
            if (type == DAY_OF_WEEK && !lastdayOfMonth) {
                Integer val = Integer.valueOf(daysOfMonth.last());
                if (val == NO_SPEC_INT) {
                    throw new CronException('\'?\' can only be specfied for Day-of-Month -OR- Day-of-Week');
                }
            }

            addToSet(NO_SPEC_INT, -1, 0, type);
            return i;
        }

        if (c == '*' || c == '/') {
            if (c == '*' && (i + 1) >= s.length()) {
                addToSet(ALL_SPEC_INT, -1, incr, type);
                return i + 1;
            } else if (c == '/' 
            		&& ((i + 1) >= s.length() || CharAt(s,i+1) == ' ' || CharAt(s,i+1) == '\t')) { 
                throw new CronException('\'/\' must be followed by an Integer');
            } else if (c == '*') {
                i++;
            }
            c = CharAt(s,i);
            if (c == '/') { // is an increment specified?
                i++;
                if (i >= s.length()) {
                    throw new CronException('Unexpected end of string.');
                }

                incr = getNumericValue(s, i);

                i++;
                if (incr > 10) {
                    i++;
                }
                if (incr > 59 && (type == SECOND || type == MINUTE)) {
                    throw new CronException('Increment > 60 : ' + incr);
                } else if (incr > 23 && (type == HOUR)) { 
                    throw new CronException('Increment > 24 : ' + incr);
                } else if (incr > 31 && (type == DAY_OF_MONTH)) { 
                    throw new CronException('Increment > 31 : ' + incr);
                } else if (incr > 7 && (type == DAY_OF_WEEK)) { 
                    throw new CronException('Increment > 7 : ' + incr);
                } else if (incr > 12 && (type == MONTH)) {
                    throw new CronException('Increment > 12 : ' + incr);
                }
            } else {
                incr = 1;
            }

            addToSet(ALL_SPEC_INT, -1, incr, type);
            return i;
        } else if (c == 'L') {
            i++;
            if (type == DAY_OF_MONTH) {
                lastdayOfMonth = true;
            }
            if (type == DAY_OF_WEEK) {
                addToSet(7, 7, 0, type);
            }
            if(type == DAY_OF_MONTH && s.length() > i) {
                c = CharAt(s,i);
                if(c == '-') {
                    ValueSet vs = getValue(0, s, i+1);
                    lastdayOffset = vs.value;
                    if(lastdayOffset > 30)
                        throw new CronException('Offset from last day must be <= 30');
                    i = vs.pos;
                }                        
                if(s.length() > i) {
                    c = CharAt(s,i);
                    if(c == 'W') {
                        nearestWeekday = true;
                        i++;
                    }
                }
            }
            return i;
        } else if (c >= '0' && c <= '9') {
            Integer val = Integer.valueOf(String.valueOf(c));
            i++;
            if (i >= s.length()) {
                addToSet(val, -1, -1, type);
            } else {
                c = CharAt(s,i);
                if (c >= '0' && c <= '9') {
                    ValueSet vs = getValue(val, s, i);
                    val = vs.value;
                    i = vs.pos;
                }
                i = checkNext(i, s, val, type);
                return i;
            }
        } else {
            throw new CronException('Unexpected character: ' + c);
        }

        return i;
    }

    protected Integer checkNext(Integer pos, String s, Integer val, Integer type) {
        
        Integer endPosition = -1;
        Integer i = pos;

        if (i >= s.length()) {
            addToSet(val, endPosition, -1, type);
            return i;
        }

        String c = CharAt(s,pos);

        if (c.equals('L')) {
            if (type == DAY_OF_WEEK) {
                if(val < 1 || val > 7)
                    throw new CronException('Day-of-Week values must be between 1 and 7');
                lastdayOfWeek = true;
            } else {
                throw new CronException('\'L\' option is not valid here. (pos=' + i + ')');
            }
            // Set<Integer> set = getSet(type);
            SortedSet intSet = getSet(type);
            intSet.add(Integer.valueOf(val));
            i++;
            return i;
        }
        
        if (c == 'W') {
            if (type == DAY_OF_MONTH) {
                nearestWeekday = true;
            } else {
                throw new CronException('\'W\' option is not valid here. (pos=' + i + ')');
            }
            if(val > 31)
                throw new CronException('The \'W\' option does not make sense with values larger than 31 (max number of days in a month)'); 
            // Set<Integer> set = getSet(type);
            SortedSet intSet = getSet(type);
            intSet.add(Integer.valueOf(val));
            i++;
            return i;
        }

        if (c == '#') {
            if (type != DAY_OF_WEEK) {
                throw new CronException('\'#\' option is not valid here. (pos=' + i + ')');
            }
            i++;
            nthdayOfWeek = Integer.valueOf(s.substring(i));
            if (nthdayOfWeek < 1 || nthdayOfWeek > 5) {
                throw new CronException('A numeric value between 1 and 5 must follow the \'#\' option');
            }

            // Set<Integer> set = getSet(type);
            SortedSet intSet = getSet(type);
            intSet.add(Integer.valueOf(val));
            i++;
            return i;
        }

        if (c.equals('-')) {
            i++;
            c = CharAt(s,1);
            Integer v = Integer.valueOf(c);
            endPosition = v;
            i++;
            if (i >= s.length()) {
                addToSet(val, endPosition, 1, type);
                return i;
            }
            c = CharAt(s,i);
            if (c >= '0' && c <= '9') {
                ValueSet vs = getValue(v, s, i);
                Integer v1 = vs.value;
                endPosition = v1;
                i = vs.pos;
            }
            if (i < s.length() && ((c = CharAt(s,i)) == '/')) {
                i++;
                c = CharAt(s,i);
                Integer v2 = Integer.valueOf(c);
                i++;
                if (i >= s.length()) {
                    addToSet(val, endPosition, v2, type);
                    return i;
                }
                c = CharAt(s,i);
                if (c >= '0' && c <= '9') {
                    ValueSet vs = getValue(v2, s, i);
                    Integer v3 = vs.value;
                    addToSet(val, endPosition, v3, type);
                    i = vs.pos;
                    return i;
                } else {
                    addToSet(val, endPosition, v2, type);
                    return i;
                }
            } else {
                addToSet(val, endPosition, 1, type);
                return i;
            }
        }

        if (c == '/') {
            i++;
            c = CharAt(s,i);
            Integer v2 = Integer.valueOf(c);
            i++;
            if (i >= s.length()) {
                addToSet(val, endPosition, v2, type);
                return i;
            }
            c = CharAt(s,i);
            if (c >= '0' && c <= '9') {
                ValueSet vs = getValue(v2, s, i);
                Integer v3 = vs.value;
                addToSet(val, endPosition, v3, type);
                i = vs.pos;
                return i;
            } else {
                throw new CronException('Unexpected character \'' + c + '\' after \'/\'');
            }
        }

        addToSet(val, endPosition, 0, type);
        i++;
        return i;
    }

    public String getCronExpression() {
        return cronExpression;
    }
    
    /*
    public String getExpressionSummary() {
        String buf = '';

        buf += 'seconds: ';
        buf += getExpressionSetSummary(seconds);
        buf += '\n';
        buf += 'minutes: ';
        buf += getExpressionSetSummary(minutes);
        buf += '\n';
        buf += 'hours: ';
        buf += getExpressionSetSummary(hours);
        buf += '\n';
        buf += 'daysOfMonth: ';
        buf += getExpressionSetSummary(daysOfMonth);
        buf += '\n';
        buf += 'months: ';
        buf += getExpressionSetSummary(months);
        buf += '\n';
        buf += 'daysOfWeek: ';
        buf += getExpressionSetSummary(daysOfWeek);
        buf += '\n';
        buf += 'lastdayOfWeek: ';
        buf += lastdayOfWeek;
        buf += '\n';
        buf += 'nearestWeekday: ';
        buf += nearestWeekday;
        buf += '\n';
        buf += 'NthDayOfWeek: ';
        buf += nthdayOfWeek;
        buf += '\n';
        buf += 'lastdayOfMonth: ';
        buf += lastdayOfMonth;
        buf += '\n';
        buf += 'years: ';
        buf += getExpressionSetSummary(years);
        buf += '\n';

        return buf;
    }

    protected String getExpressionSetSummary(SortedSet expressionSet) {

        if (expressionSet.contains(NO_SPEC)) return '?';
        if (expressionSet.contains(ALL_SPEC)) return '*';

        String buffer = '';

        SortedSetIterator itr = expressionSet.iterator();
        boolean first = true;
        while (itr.hasNext()) {
            Integer iVal = itr.next();
            String val = (String) String.valueOf(iVal);
            if (!first) buffer += ',';
            buffer += val;
            first = false;
        }

        return buffer;
    }
    */
	
	/*
    protected String getExpressionSetSummary(List<Integer> lst) {
    	Set<Integer> intSet = new Set<Integer>();
    	intSet.addAll(lst);
		return getExpressionSetSummary(intSet);
    }
    */

    protected Integer skipWhiteSpace(Integer i, String s) {
    	// Get the Character at the specified index
    	String c = CharAt(s,i);
    	
        // for (; (i < s.length() && (c.equals(' ') || c.equals('\t'))); i++) {
        while ((c.equals(' ') || c.equals('\t'))) {
            if (++i == s.length()) break;
            else c = CharAt(s,i);
        }

        return i;
    }

    protected Integer findNextWhiteSpace(Integer i, String s) {
    	// Get the Character at the specified index
    	String c = CharAt(s,i);
    	
        // for (; (i < s.length() && (c.equals(' ') || c.equals('\t'))); i++) {
        while ((!c.equals(' ') || !c.equals('\t'))) {
            if (++i == s.length()) break;
            else c = CharAt(s,i);
        }

        return i;
    }

    protected void addToSet(Integer val, Integer endVal, Integer incr, Integer type) {
        
        // Set<Integer> set = getSet(type);
        SortedSet intSet = getSet(type);

        if (type == SECOND || type == MINUTE) {
            if ((val < 0 || val > 59 || endVal > 59) && (val != ALL_SPEC_INT)) {
                throw new CronException('Minute and Second values must be between 0 and 59');
            }
        } else if (type == HOUR) {
            if ((val < 0 || val > 23 || endVal > 23) && (val != ALL_SPEC_INT)) {
                throw new CronException('Hour values must be between 0 and 23');
            }
        } else if (type == DAY_OF_MONTH) {
            if ((val < 1 || val > 31 || endVal > 31) && (val != ALL_SPEC_INT) 
                    && (val != NO_SPEC_INT)) {
                throw new CronException('Day of month values must be between 1 and 31');
            }
        } else if (type == MONTH) {
            if ((val < 1 || val > 12 || endVal > 12) && (val != ALL_SPEC_INT)) {
                throw new CronException('Month values must be between 1 and 12');
            }
        } else if (type == DAY_OF_WEEK) {
            if ((val == 0 || val > 7 || endVal > 7) && (val != ALL_SPEC_INT)
                    && (val != NO_SPEC_INT)) {
                throw new CronException('Day-of-Week values must be between 1 and 7');
            }
        }

        if ((incr == 0 || incr == -1) && val != ALL_SPEC_INT) {
            if (val != -1) {
                intSet.add(Integer.valueOf(val));
            } else {
                intSet.add(NO_SPEC);
            }
            
            return;
        }

        Integer startAt = val;
        Integer stopAt = endVal;

        if (val == ALL_SPEC_INT && incr <= 0) {
            incr = 1;
            intSet.add(ALL_SPEC); // put in a marker, but also fill values
        }

        if (type == SECOND || type == MINUTE) {
            if (stopAt == -1) {
                stopAt = 59;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 0;
            }
        } else if (type == HOUR) {
            if (stopAt == -1) {
                stopAt = 23;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 0;
            }
        } else if (type == DAY_OF_MONTH) {
            if (stopAt == -1) {
                stopAt = 31;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 1;
            }
        } else if (type == MONTH) {
            if (stopAt == -1) {
                stopAt = 12;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 1;
            }
        } else if (type == DAY_OF_WEEK) {
            if (stopAt == -1) {
                stopAt = 7;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 1;
            }
        } else if (type == YEAR) {
            if (stopAt == -1) {
                stopAt = MAX_YEAR;
            }
            if (startAt == -1 || startAt == ALL_SPEC_INT) {
                startAt = 1970;
            }
        }

        // if the end of the range is before the start, then we need to overflow Integero 
        // the next day, month etc. This is done by adding the maximum amount for that 
        // type, and using modulus max to determine the value being added.
        Integer max = -1;
        if (stopAt < startAt) {
            if (type == SECOND || type == MINUTE) max = 60;
            else if (type == HOUR) max = 24;
            else if (type == MONTH) max = 12;
            else if (type == DAY_OF_WEEK) max = 7;
            else if (type == DAY_OF_MONTH) max = 31;
            else if (type == YEAR) throw new CronException('Start year must be less than stop year');
            else throw new CronException('Unexpected type encountered');
            stopAt += max;
        }

        for (Integer i = startAt; i <= stopAt; i += incr) {
            if (max == -1) {
                // ie: there's no max to overflow over
                intSet.add(Integer.valueOf(i));
            } else {
                // take the modulus to get the real value
                Integer i2 = Math.mod(i,max);

                // 1-indexed ranges should not include 0, and should include their max
                if (i2 == 0 && (type == MONTH || type == DAY_OF_WEEK || type == DAY_OF_MONTH) ) {
                    i2 = max;
                }

                intSet.add(Integer.valueOf(i2));
            }
        }
    }

	protected SortedSet getSet(Integer type) {
    // protected Set<Integer> getSet(Integer type) {
    	if (type == SECOND) return seconds;
    	else if (type == MINUTE) return minutes;
    	else if (type == HOUR) return hours;
    	else if (type == DAY_OF_MONTH) return daysOfMonth;
    	else if (type == MONTH) return months;
    	else if (type == DAY_OF_WEEK) return daysOfWeek;
    	else if (type == YEAR) return years; 
        else return null;
    }

    protected ValueSet getValue(Integer v, String s, Integer i) {
        String c = CharAt(s,i);
        String s1 = String.valueOf(v);
        while (c >= '0' && c <= '9') {
            s1 += c;
            i++;
            if (i >= s.length()) {
                break;
            }
            c = CharAt(s,i);
        }
        ValueSet val = new ValueSet();
        
        val.pos = (i < s.length()) ? i : i + 1;
        val.value = Integer.valueOf(s1);
        return val;
    }

    protected Integer getNumericValue(String s, Integer i) {
        Integer endOfVal = findNextWhiteSpace(i, s);
        String val = s.substring(i, endOfVal);
        return Integer.valueOf(val);
    }

    protected Integer getMonthNumber(String s) {
        Integer i = (Integer) monthMap.get(s);
        if (i == null) return -1;
        return i;
    }

    protected Integer getDayOfWeekNumber(String s) {
        Integer i = (Integer) dayMap.get(s);
        if (i == null) return -1;
		return i;
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // Computation Functions
    //
    ////////////////////////////////////////////////////////////////////////////

	/*
    public Date getTimeAfter(Date afterTime) {

        // Computation is based on Gregorian year only.
        Calendar cl = new java.util.GregorianCalendar(getTimeZone()); 

        // move ahead one second, since we're computing the time *after* the
        // given time
        afterTime = new Date(afterTime.getTime() + 1000);
        // CronTrigger does not deal with milliseconds
        cl.setTime(afterTime);
        cl.set(Calendar.MILLISECOND, 0);

        boolean gotOne = false;
        // loop until we've computed the next time, or we've past the endTime
        while (!gotOne) {

            //if (endTime != null && cl.getTime().after(endTime)) return null;
            if(cl.get(Calendar.YEAR) > 2999) { // prevent endless loop...
                return null;
            }

            // Set<Integer> st;
            SortedSet st;
            Integer t = 0;

            Integer sec = cl.get(Calendar.SECOND);
            Integer min = cl.get(Calendar.MINUTE);

            // get second.................................................
            st = seconds.tailSet(Integer.valueOf(sec));
            if (st != null && st.size() != 0) {
                sec = Integer.valueOf(st.first());
            } else {
                sec = Integer.valueOf(seconds.first());
                min++;
                cl.set(Calendar.MINUTE, min);
            }
            cl.set(Calendar.SECOND, sec);

            min = cl.get(Calendar.MINUTE);
            Integer hr = cl.get(Calendar.HOUR_OF_DAY);
            t = -1;

            // get minute.................................................
            st = minutes.tailSet(Integer.valueOf(min));
            if (st != null && st.size() != 0) {
                t = min;
                min = Integer.valueOf(st.first());
            } else {
                min = Integer.valueOf(minutes.first());
                hr++;
            }
            if (min != t) {
                cl.set(Calendar.SECOND, 0);
                cl.set(Calendar.MINUTE, min);
                setCalendarHour(cl, hr);
                continue;
            }
            cl.set(Calendar.MINUTE, min);

            hr = cl.get(Calendar.HOUR_OF_DAY);
            Integer day = cl.get(Calendar.DAY_OF_MONTH);
            t = -1;

            // get hour...................................................
            st = hours.tailSet(Integer.valueOf(hr));
            if (st != null && st.size() != 0) {
                t = hr;
                hr = Integer.valueOf(st.first());
            } else {
                hr = Integer.valueOf(hours.first());
                day++;
            }
            if (hr != t) {
                cl.set(Calendar.SECOND, 0);
                cl.set(Calendar.MINUTE, 0);
                cl.set(Calendar.DAY_OF_MONTH, day);
                setCalendarHour(cl, hr);
                continue;
            }
            cl.set(Calendar.HOUR_OF_DAY, hr);

            day = cl.get(Calendar.DAY_OF_MONTH);
            Integer mon = cl.get(Calendar.MONTH) + 1;
            // '+ 1' because calendar is 0-based for this field, and we are
            // 1-based
            t = -1;
            Integer tmon = mon;
            
            // get day...................................................
            boolean dayOfMSpec = !daysOfMonth.contains(NO_SPEC);
            boolean dayOfWSpec = !daysOfWeek.contains(NO_SPEC);
            if (dayOfMSpec && !dayOfWSpec) { // get day by day of month rule
                st = daysOfMonth.tailSet(Integer.valueOf(day));
                if (lastdayOfMonth) {
                    if(!nearestWeekday) {
                        t = day;
                        day = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));
                        day -= lastdayOffset;
                    } else {
                        t = day;
                        day = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));
                        day -= lastdayOffset;
                        
                        java.util.Calendar tcal = java.util.Calendar.getInstance(getTimeZone());
                        tcal.set(Calendar.SECOND, 0);
                        tcal.set(Calendar.MINUTE, 0);
                        tcal.set(Calendar.HOUR_OF_DAY, 0);
                        tcal.set(Calendar.DAY_OF_MONTH, day);
                        tcal.set(Calendar.MONTH, mon - 1);
                        tcal.set(Calendar.YEAR, cl.get(Calendar.YEAR));
                        
                        Integer ldom = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));
                        Integer dow = tcal.get(Calendar.DAY_OF_WEEK);

                        if(dow == Calendar.SATURDAY && day == 1) {
                            day += 2;
                        } else if(dow == Calendar.SATURDAY) {
                            day -= 1;
                        } else if(dow == Calendar.SUNDAY && day == ldom) { 
                            day -= 2;
                        } else if(dow == Calendar.SUNDAY) { 
                            day += 1;
                        }
                    
                        tcal.set(Calendar.SECOND, sec);
                        tcal.set(Calendar.MINUTE, min);
                        tcal.set(Calendar.HOUR_OF_DAY, hr);
                        tcal.set(Calendar.DAY_OF_MONTH, day);
                        tcal.set(Calendar.MONTH, mon - 1);
                        Date nTime = tcal.getTime();
                        if(nTime.before(afterTime)) {
                            day = 1;
                            mon++;
                        }
                    }
                } else if(nearestWeekday) {
                    t = day;
                    day = Integer.valueOf(daysOfMonth.first());

                    java.util.Calendar tcal = java.util.Calendar.getInstance(getTimeZone());
                    tcal.set(Calendar.SECOND, 0);
                    tcal.set(Calendar.MINUTE, 0);
                    tcal.set(Calendar.HOUR_OF_DAY, 0);
                    tcal.set(Calendar.DAY_OF_MONTH, day);
                    tcal.set(Calendar.MONTH, mon - 1);
                    tcal.set(Calendar.YEAR, cl.get(Calendar.YEAR));
                    
                    Integer ldom = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));
                    Integer dow = tcal.get(Calendar.DAY_OF_WEEK);

                    if(dow == Calendar.SATURDAY && day == 1) {
                        day += 2;
                    } else if(dow == Calendar.SATURDAY) {
                        day -= 1;
                    } else if(dow == Calendar.SUNDAY && day == ldom) { 
                        day -= 2;
                    } else if(dow == Calendar.SUNDAY) { 
                        day += 1;
                    }
                        
                
                    tcal.set(Calendar.SECOND, sec);
                    tcal.set(Calendar.MINUTE, min);
                    tcal.set(Calendar.HOUR_OF_DAY, hr);
                    tcal.set(Calendar.DAY_OF_MONTH, day);
                    tcal.set(Calendar.MONTH, mon - 1);
                    Date nTime = tcal.getTime();
                    if(nTime.before(afterTime)) {
                        day = Integer.valueOf(daysOfMonth.first());
                        mon++;
                    }
                } else if (st != null && st.size() != 0) {
                    t = day;
                    day = Integer.valueOf(st.first());
                    // make sure we don't over-run a short month, such as february
                    Integer lastDay = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));
                    if (day > lastDay) {
                        day = Integer.valueOf(daysOfMonth.first());
                        mon++;
                    }
                } else {
                    day = Integer.valueOf(daysOfMonth.first());
                    mon++;
                }
                
                if (day != t || mon != tmon) {
                    cl.set(Calendar.SECOND, 0);
                    cl.set(Calendar.MINUTE, 0);
                    cl.set(Calendar.HOUR_OF_DAY, 0);
                    cl.set(Calendar.DAY_OF_MONTH, day);
                    cl.set(Calendar.MONTH, mon - 1);
                    // '- 1' because calendar is 0-based for this field, and we
                    // are 1-based
                    continue;
                }
            } else if (dayOfWSpec && !dayOfMSpec) { // get day by day of week rule
                if (lastdayOfWeek) { // are we looking for the last XXX day of
                    // the month?
                    Integer dow = Integer.valueOf(daysOfWeek.first()); // desired
                    // d-o-w
                    Integer cDow = cl.get(Calendar.DAY_OF_WEEK); // current d-o-w
                    Integer daysToAdd = 0;
                    if (cDow < dow) {
                        daysToAdd = dow - cDow;
                    }
                    if (cDow > dow) {
                        daysToAdd = dow + (7 - cDow);
                    }

                    Integer lDay = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));

                    if (day + daysToAdd > lDay) { // did we already miss the
                        // last one?
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, 1);
                        cl.set(Calendar.MONTH, mon);
                        // no '- 1' here because we are promoting the month
                        continue;
                    }

                    // find date of last occurrence of this day in this month...
                    while ((day + daysToAdd + 7) <= lDay) {
                        daysToAdd += 7;
                    }

                    day += daysToAdd;

                    if (daysToAdd > 0) {
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, day);
                        cl.set(Calendar.MONTH, mon - 1);
                        // '- 1' here because we are not promoting the month
                        continue;
                    }

                } else if (nthdayOfWeek != 0) {
                    // are we looking for the Nth XXX day in the month?
                    Integer dow = Integer.valueOf(daysOfWeek.first()); // desired
                    // d-o-w
                    Integer cDow = cl.get(Calendar.DAY_OF_WEEK); // current d-o-w
                    Integer daysToAdd = 0;
                    if (cDow < dow) {
                        daysToAdd = dow - cDow;
                    } else if (cDow > dow) {
                        daysToAdd = dow + (7 - cDow);
                    }

                    boolean dayShifted = false;
                    if (daysToAdd > 0) {
                        dayShifted = true;
                    }

                    day += daysToAdd;
                    Integer weekOfMonth = day / 7;
                    if (Math.mod(day,7) > 0) {
                        weekOfMonth++;
                    }

                    daysToAdd = (nthdayOfWeek - weekOfMonth) * 7;
                    day += daysToAdd;
                    if (daysToAdd < 0
                            || day > getLastDayOfMonth(mon, cl
                                    .get(Calendar.YEAR))) {
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, 1);
                        cl.set(Calendar.MONTH, mon);
                        // no '- 1' here because we are promoting the month
                        continue;
                    } else if (daysToAdd > 0 || dayShifted) {
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, day);
                        cl.set(Calendar.MONTH, mon - 1);
                        // '- 1' here because we are NOT promoting the month
                        continue;
                    }
                } else {
                    Integer cDow = cl.get(Calendar.DAY_OF_WEEK); // current d-o-w
                    Integer dow = Integer.valueOf(daysOfWeek.first()); // desired
                    // d-o-w
                    st = daysOfWeek.tailSet(Integer.valueOf(cDow));
                    if (st != null && st.size() > 0) {
                        dow = Integer.valueOf(st.first());
                    }

                    Integer daysToAdd = 0;
                    if (cDow < dow) {
                        daysToAdd = dow - cDow;
                    }
                    if (cDow > dow) {
                        daysToAdd = dow + (7 - cDow);
                    }

                    Integer lDay = getLastDayOfMonth(mon, cl.get(Calendar.YEAR));

                    if (day + daysToAdd > lDay) { // will we pass the end of
                        // the month?
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, 1);
                        cl.set(Calendar.MONTH, mon);
                        // no '- 1' here because we are promoting the month
                        continue;
                    } else if (daysToAdd > 0) { // are we swithing days?
                        cl.set(Calendar.SECOND, 0);
                        cl.set(Calendar.MINUTE, 0);
                        cl.set(Calendar.HOUR_OF_DAY, 0);
                        cl.set(Calendar.DAY_OF_MONTH, day + daysToAdd);
                        cl.set(Calendar.MONTH, mon - 1);
                        // '- 1' because calendar is 0-based for this field,
                        // and we are 1-based
                        continue;
                    }
                }
            } else { // dayOfWSpec && !dayOfMSpec
                throw new CronException('Support for specifying both a day-of-week AND a day-of-month parameter is not implemented.');
                // TODO:
            }
            cl.set(Calendar.DAY_OF_MONTH, day);

            mon = cl.get(Calendar.MONTH) + 1;
            // '+ 1' because calendar is 0-based for this field, and we are
            // 1-based
            Integer yr = cl.get(Calendar.YEAR);
            t = -1;

            // test for expressions that never generate a valid fire date,
            // but keep looping...
            if (yr > MAX_YEAR) {
                return null;
            }

            // get month...................................................
            st = months.tailSet(Integer.valueOf(mon));
            if (st != null && st.size() != 0) {
                t = mon;
                mon = Integer.valueOf(st.first());
            } else {
                mon = Integer.valueOf(months.first());
                yr++;
            }
            if (mon != t) {
                cl.set(Calendar.SECOND, 0);
                cl.set(Calendar.MINUTE, 0);
                cl.set(Calendar.HOUR_OF_DAY, 0);
                cl.set(Calendar.DAY_OF_MONTH, 1);
                cl.set(Calendar.MONTH, mon - 1);
                // '- 1' because calendar is 0-based for this field, and we are
                // 1-based
                cl.set(Calendar.YEAR, yr);
                continue;
            }
            cl.set(Calendar.MONTH, mon - 1);
            // '- 1' because calendar is 0-based for this field, and we are
            // 1-based

            yr = cl.get(Calendar.YEAR);
            t = -1;

            // get year...................................................
            st = years.tailSet(Integer.valueOf(yr));
            if (st != null && st.size() != 0) {
                t = yr;
                yr = Integer.valueOf(st.first());
            } else {
                return null; // ran out of years...
            }

            if (yr != t) {
                cl.set(Calendar.SECOND, 0);
                cl.set(Calendar.MINUTE, 0);
                cl.set(Calendar.HOUR_OF_DAY, 0);
                cl.set(Calendar.DAY_OF_MONTH, 1);
                cl.set(Calendar.MONTH, 0);
                // '- 1' because calendar is 0-based for this field, and we are
                // 1-based
                cl.set(Calendar.YEAR, yr);
                continue;
            }
            cl.set(Calendar.YEAR, yr);

            gotOne = true;
        } // while( !done )

        return cl.getTime();
    }
    */

    /**
     * Advance the calendar to the particular hour paying particular attention
     * to daylight saving problems.
     * 
     * @param cal
     * @param hour
     */
    /* 
    protected void setCalendarHour(Calendar cal, Integer theHour) {
        cal.set(java.util.Calendar.HOUR_OF_DAY, theHour);
        if (cal.get(java.util.Calendar.HOUR_OF_DAY) != theHour && theHour != 24) {
            cal.set(java.util.Calendar.HOUR_OF_DAY, theHour + 1);
        }
    }
    */

    /**
     * NOT YET IMPLEMENTED: Returns the time before the given time
     * that the <code>CronExpression</code> matches.
     */ 
    public Date getTimeBefore(Date endTime) { 
        // TODO: implement QUARTZ-423
        return null;
    }

    /**
     * NOT YET IMPLEMENTED: Returns the final time that the 
     * <code>CronExpression</code> will match.
     */
    public Date getFinalFireTime() {
        // TODO: implement QUARTZ-423
        return null;
    }
    
    protected boolean isLeapYear(Integer y) {
        return ((Math.mod(y,4) == 0 && Math.mod(y,100) != 0) || (Math.mod(y,400) == 0));
    }

    protected Integer getLastDayOfMonth(Integer monthNum, Integer yearNum) {
		if (monthNum == 1) return 31;
        else if (monthNum == 2) return (isLeapYear(yearNum)) ? 29 : 28;
        else if (monthNum == 3) return 31;
        else if (monthNum == 4) return 30;
        else if (monthNum == 5) return 31;
        else if (monthNum == 6) return 30;
        else if (monthNum == 7) return 31;
        else if (monthNum == 8) return 31;
        else if (monthNum == 9) return 30;
        else if (monthNum == 10) return 31;
        else if (monthNum == 11) return 30;
        else if (monthNum == 12) return 31;
       	else throw new CronException('Illegal month number: ' + monthNum);
    }
    
    // Given a string and the index of a position in the string,
	// return the character at that position. If there is no
	// character, return an empty string.
	private static String CharAt(String str, Integer index) {
		String ch = '';
		try {
			ch = str.substring(index, index+1);
		} catch (Exception ex) {
			// There is no character at that position.
			return '';
		}
		return ch;
	}
    
 	// Helper Class   
    public class ValueSet {
    	public Integer value;
    	public Integer pos;
	}
         
}