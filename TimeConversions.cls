/* **********************************************************************************************
* TimeConversions Class
* Created by: Michael Smith/Force2b, 04/06/2010
* Adapted by: Zach McElrath/Skoodat, 01/07/2012
*
************************************************************************************************ */
public class TimeConversions {
   
   /* -------------------------------------------------------------------------------------
   * Returns an Integer  of the Timezone Offset from Eastern Time for the
   * currently logged in user
   *
   * This is used to convert the String DateTime (that is in Eastern Time) into a
   * DateTime value in SalesForce. The default behavior of SFC converts the string into
   * a local datetime value, but we need to get into Eastern Time.
   * ------------------------------------------------------------------------------------- */
   public static Integer GetCurrentUserTZOffsetFromEastern() {
      
      Map<String, Integer[]> tzSIDKeys = getTZSidKeys();
      
      User user = [SELECT ID, TimeZoneSidKey FROM User WHERE ID = :UserInfo.getUserId() LIMIT 1];
      
      Date[] dstDatesNow = GetDSTDates(System.Today().year());
      Integer UsersTZOffset = 0;
      
      if (tzSIDKeys.get(user.TimeZoneSidKey) != null) {
         // Get the base timezone offset from GMT for the user
         if (System.Today() >= dstDatesNow[0] && System.Today() <= dstDatesNow[1]) UsersTZOffset = tzSIDKeys.get(user.TimeZoneSidKey)[1];
         else UsersTZOffset = tzSIDKeys.get(user.TimeZoneSidKey)[0];
         system.debug(LoggingLevel.Error, 'Base TimeZone for Current User=' + user.TimeZoneSidKey + '/' + UsersTZOffset );
         
         // Now make it a timezone offset from EASTERN time
         Integer EasternTZOffset = 0;
         if (System.Today() >= dstDatesNow[0] && System.Today() <= dstDatesNow[1]) EasternTZOffset = tzSIDKeys.get('America/New_York')[1];
         else EasternTZOffset = tzSIDKeys.get('America/New_York')[0];
         UsersTZOffset = Math.abs(EasternTZOffset) - Math.abs(UsersTZOffset);
         system.debug(LoggingLevel.Error, 'TimeZone Offset to Eastern Time=' + UsersTZOffset );
      }
      return UsersTZOffset ;
   }
   
   /* -------------------------------------------------------------------------------------
   * Returns an Integer  of the Timezone Offset from GMT for the currently logged in user
   *
   * This is used to convert the String DateTime (that is in GMT) into a
   * DateTime value in SalesForce. The default behavior of SFC converts the string into
   * a local datetime value, but we need to get into Eastern Time.
   * ------------------------------------------------------------------------------------- */
   public static Integer GetCurrentUserTZOffsetFromGMT() {
      
      Map<String, Integer[]> tzSIDKeys = getTZSidKeys();
      
      User user = [SELECT ID, TimeZoneSidKey FROM User WHERE ID = :UserInfo.getUserId() LIMIT 1];
      
      Date[] dstDatesNow = GetDSTDates(System.Today().year());
      Integer UsersTZOffset = 0;
      
      if (tzSIDKeys.get(user.TimeZoneSidKey) != null) {
         // Get the base timezone offset from GMT for the user
         if (System.Today() >= dstDatesNow[0] && System.Today() <= dstDatesNow[1]) UsersTZOffset = tzSIDKeys.get(user.TimeZoneSidKey)[1];
         else UsersTZOffset = tzSIDKeys.get(user.TimeZoneSidKey)[0];
         system.debug(LoggingLevel.Error, 'Base TimeZone for Current User=' + user.TimeZoneSidKey + '/' + UsersTZOffset );
         system.debug(LoggingLevel.Error, 'TimeZone Offset to GMT=' + UsersTZOffset );
      }
      return UsersTZOffset ;
   }
   
   /* -------------------------------------------------------------------------------------
   * Returns a String Collection of the Timezone Codes based on the Timezone Offset Passed
   * for the date passed.
   *
   * Based on a table from: http://en.wikipedia.org/wiki/Zone.tab
   *
   * getTimeZoneCode[0] = Display Text (ex: EDT)
   * getTimeZoneCode[1] = DateTime.Format() parameter (ex: America/New_York)
   * ------------------------------------------------------------------------------------- */
   public static String[] GetTimeZoneCode(Integer tzOffset, Date theDate, Boolean isDSTObserved) {
      Date[] dstDates = getDSTDates(theDate.year()); // [0]=startDate, [1]=endDate
      boolean isDSTOn = (theDate >= dstDates[0] && theDate <= dstDates[1]);
      
      if (tzOffset == 0) return new String[]{' GMT', 'Europe/London' };
      else if (tzOffset == 4) return new String[]{' AST (UTC-04)', 'America/Puerto_Rico' };
      else if (tzOffset == 5 && isDSTOn && isDSTObserved) return new String[]{' EDT (UTC-04)', 'America/New_York' };
      else if (tzOffset == 5) return new String[]{' EST (UTC-05)', 'America/New_York' };
      else if (tzOffset == 6 && isDSTOn && isDSTObserved) return new String[]{' CDT (UTC-05)', 'America/Chicago' };
      else if (tzOffset == 6) return new String[]{' CST (UTC-06)', 'America/Chicago' };
      else if (tzOffset == 7 && !isDSTObserved)         return new String[]{' MST (UTC-07)', 'America/Phoenix' };
      else if (tzOffset == 7 && isDSTOn && isDSTObserved) return new String[]{' MDT (UTC-06)', 'America/Denver' };
      else if (tzOffset == 7) return new String[]{' MST (UTC-07)', 'America/Denver' };
      else if (tzOffset == 8 && isDSTOn && isDSTObserved) return new String[]{' PDT (UTC-07)', 'America/Los_Angeles' };
      else if (tzOffset == 8) return new String[]{' PST (UTC-08)', 'America/Los_Angeles' };
      else if (tzOffset == 9 && isDSTOn && isDSTObserved) return new String[]{' AKDT (UTC-08)', 'America/Anchorage' };
      else if (tzOffset == 9) return new String[]{' AKST (UTC-09)', 'America/Anchorage' };
      else if (tzOffset == 10 && !isDSTObserved)        return new String[]{' HST (UTC-10)', 'Pacific/Honolulu' };
      else if (tzOffset == 10 && isDSTOn && isDSTObserved) return new String[]{' HDT (UTC-09)', 'America/Adak' };
      else if (tzOffset == 10) return new String[]{' HST (UTC-10)', 'America/Adak' };
      else if (tzOffset == 11) return new String[]{' HST (UTC-10)', 'Pacific/Pago_Pago' };
      else return new String[]{' UTC-' + tzOffset, 'GMT' };
   }
   
   /* -------------------------------------------------------------------------------------
   * Returns a date Collection of Start/End dates for US Daylight Saving Time
   * for the specified year.
   *
   * Based on code from: http://www.webexhibits.org/daylightsaving/b2.html
   * ------------------------------------------------------------------------------------- */
   public static Date[] GetDSTDates(Integer theYear) {
      Long thisYear;
      Long AprilDate;
      Long OctoberDate;
      Long MarchDate;
      Long NovemberDate;
      Long longSeven = 7;
      thisYear = Math.round(theYear);
      
      AprilDate = Math.mod(2+6 * thisYear - Math.floor(thisYear / 4).longValue(), longSeven) + 1;
      OctoberDate=  Math.mod(31-( Math.floor(thisYear * 5 / 4).longValue() + 1), longSeven);
      
      MarchDate = 14 - Math.mod(Math.floor(1 + thisYear * 5 / 4).LongValue(), longSeven);
      NovemberDate = 7 - Math.mod(Math.floor (1 + thisYear * 5 / 4).LongValue(), longSeven);
      
      string startDate = (thisYear > 2006 ? ('03/'+MarchDate) : ('04/'+AprilDate)) + '/' + thisYear;
      string endDate = (thisYear > 2006 ? ('11/'+NovemberDate):('10/'+OctoberDate))+ '/' + thisYear;
      
      Date[] rtnDates = new List<Date>();
      rtnDates.add(Date.parse(startDate));
      rtnDates.add(Date.parse(endDate));
      return rtnDates;
   }
   
   public static Map<String, Integer[]> getTZSidKeys() {
      return new Map<String, Integer[]>{
	      'America/Adak' => new Integer[]{-10, -9},
	      'America/Anchorage' => new Integer[]{-9, -8},
	      'America/Chicago' => new Integer[]{-6, -5},
	      'America/Denver' => new Integer[]{-7, -6},
	      'America/Detroit' => new Integer[]{-5, -4},
	      'America/Halifax' => new Integer[]{-4, -3},
	      'America/Indianapolis' => new Integer[]{-5, -4},
	      'America/Los_Angeles' => new Integer[]{-8, -7},
	      'America/Montreal' => new Integer[]{-5, -4},
	      'America/New_York' => new Integer[]{-5, -4},
	      'America/Panama' => new Integer[]{-5, -5},
	      'America/Phoenix' => new Integer[]{-7, -7},
	      'America/Puerto_Rico' => new Integer[]{-4, -4},
	      'America/Toronto' => new Integer[]{-5, -4},
	      'America/Vancouver' => new Integer[]{-8, -7},
	      'Europe/London' => new Integer[]{0, 1},
	      'Pacific/Honolulu' => new Integer[]{-10, -10},
	      'Pacific/Pago_Pago' => new Integer[]{-11, -11}
      };
   }
}