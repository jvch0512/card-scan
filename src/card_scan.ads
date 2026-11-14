--  Card number detection: Luhn, issuer ranges, masking and a line scanner.
package Card_Scan is

   type Brand is (Unknown, Visa, Mastercard, Amex, Discover, Diners, JCB);

   type Match is record
      Column   : Positive;   --  1-based start of the number in the line
      Number_Len : Natural;
      Masked   : String (1 .. 19);  --  padded with spaces; use Masked (1 .. Number)
      Kind     : Brand;
      Is_Test  : Boolean;
   end record;

   type Match_Array is array (Positive range <>) of Match;
   Max_Matches : constant := 64;

   function Luhn_Valid (Number : String) return Boolean;
   --  Number must contain only '0' .. '9'.

   function Brand_Of (Number : String) return Brand;
   function Brand_Name (B : Brand) return String;
   function Is_Test_Number (Number : String) return Boolean;
   function Mask (Number : String) return String;
   --  First six and last four kept, the rest replaced by '*'.

   procedure Scan_Line
     (Line : String; Found : out Match_Array; Count : out Natural);
   --  Finds up to Max_Matches candidates (13 .. 19 digits, single space or
   --  hyphen separators, not part of a longer digit run) that pass Luhn.

end Card_Scan;
