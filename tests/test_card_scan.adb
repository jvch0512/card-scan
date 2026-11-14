with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Card_Scan;        use Card_Scan;

procedure Test_Card_Scan is
   Passed : Natural := 0;
   Failed : Natural := 0;

   procedure Check (Cond : Boolean; Name : String) is
   begin
      if Cond then
         Passed := Passed + 1;
      else
         Failed := Failed + 1;
         Put_Line ("FAIL: " & Name);
      end if;
   end Check;

   Found : Match_Array (1 .. Max_Matches);
   Count : Natural;

   function Scan (S : String) return Natural is
   begin
      Scan_Line (S, Found, Count);
      return Count;
   end Scan;

   function Run (Cmd : String) return Integer is
      function System (C : String) return Integer;
      pragma Import (C, System, "system");
      R : constant Integer := System (Cmd & " >/dev/null 2>&1" & ASCII.NUL);
   begin
      return R / 256;
   end Run;
begin
   --  Luhn
   Check (Luhn_Valid ("4111111111111111"), "luhn visa test");
   Check (Luhn_Valid ("378282246310005"), "luhn amex test");
   Check (Luhn_Valid ("79927398713"), "luhn classic example");
   Check (not Luhn_Valid ("4111111111111112"), "luhn off by one");
   Check (not Luhn_Valid ("4111a11111111111"), "luhn non digit");
   Check (not Luhn_Valid (""), "luhn empty");
   Check (Luhn_Valid ("0"), "luhn zero");

   --  Brands
   Check (Brand_Of ("4532000000000009") = Visa, "visa 16");
   Check (Brand_Of ("4222222222222") = Visa, "visa 13");
   Check (Brand_Of ("5100000000000008") = Mastercard, "mc 51");
   Check (Brand_Of ("5555555555554444") = Mastercard, "mc 55");
   Check (Brand_Of ("2223003122003222") = Mastercard, "mc 2-series");
   Check (Brand_Of ("2720000000000000") = Mastercard, "mc 2720");
   Check (Brand_Of ("2721000000000000") = Unknown, "mc 2721 out of range");
   Check (Brand_Of ("5600000000000000") = Unknown, "56 is not mc");
   Check (Brand_Of ("378282246310005") = Amex, "amex 37");
   Check (Brand_Of ("340000000000009") = Amex, "amex 34");
   Check (Brand_Of ("3782822463100") = Unknown, "amex wrong length");
   Check (Brand_Of ("6011000000000004") = Discover, "discover 6011");
   Check (Brand_Of ("6500000000000002") = Discover, "discover 65");
   Check (Brand_Of ("30569309025904") = Diners, "diners 305");
   Check (Brand_Of ("36000000000008") = Diners, "diners 36");
   Check (Brand_Of ("3528000000000007") = JCB, "jcb 3528");
   Check (Brand_Of ("3589000000000000") = JCB, "jcb 3589");
   Check (Brand_Of ("3590000000000000") = Unknown, "jcb 3590 out");
   Check (Brand_Of ("123") = Unknown, "too short");
   Check (Brand_Name (Amex) = "American Express", "brand name");

   --  Masking
   Check (Mask ("4532000000000009") = "453200******0009", "mask 16");
   Check (Mask ("370000000000002") = "370000*****0002", "mask 15");
   Check (Mask ("4111111111111111")'Length = 16, "mask keeps length");

   --  Test numbers
   Check (Is_Test_Number ("4111111111111111"), "test number visa");
   Check (Is_Test_Number ("378282246310005"), "test number amex");
   Check (not Is_Test_Number ("4532000000000009"), "not a test number");

   --  Scanner
   Check (Scan ("no digits here") = 0, "scan none");
   Check (Scan ("card=4532000000000009 ok") = 1, "scan plain");
   Check (Found (1).Column = 6 and then Found (1).Number_Len = 16, "scan column and length");
   Check (Found (1).Masked (1 .. 16) = "453200******0009", "scan masked");
   Check (Found (1).Kind = Visa and then not Found (1).Is_Test, "scan kind");
   Check (Scan ("4532 0000 0000 0009") = 1, "scan spaces");
   Check (Scan ("4532-0000-0000-0009") = 1, "scan hyphens");
   Check (Found (1).Column = 1, "scan group start");
   Check (Scan ("4532  0000 0000 0009") = 0, "double space breaks the number");
   Check (Scan ("x4532000000000009") = 1, "letter before is a boundary");
   Check (Scan ("14532000000000009") = 0, "digit run too long or invalid");
   Check (Scan ("45320000000000090") = 0, "17 digits not luhn");
   Check (Scan ("4532000000000009, 5100000000000008") = 2, "two numbers on a line");
   Check (Scan ("4111111111111111") = 1 and then Found (1).Is_Test, "test card flagged");
   Check (Scan ("12345678901234567890123") = 0, "23 digit id ignored");
   Check (Scan ("2026-11-14 09:12:01") = 0, "timestamp ignored");
   Check (Scan ("") = 0, "empty line");
   Check (Scan ("4532000000000009") = 1 and then Found (1).Column = 1, "number at line end");

   --  CLI
   if Ada.Directories.Exists ("bin/card-scan") then
      Check (Run ("./bin/card-scan examples/data") = 0, "cli ok");
      Check (Run ("./bin/card-scan examples/data --fail-on high") = 1, "cli fail-on high");
      Check (Run ("./bin/card-scan examples/data/notes.txt --fail-on any") = 0, "cli clean file");
      Check (Run ("./bin/card-scan /no/such/dir") = 2, "cli missing path");
      Check (Run ("./bin/card-scan") = 2, "cli usage");
      Check (Run ("./bin/card-scan examples/data --bogus") = 2, "cli bad flag");
      Check (Run ("./bin/card-scan examples/data --fail-on nope") = 2, "cli bad fail-on");
   end if;

   Put_Line (Natural'Image (Passed) & " passed," & Natural'Image (Failed) & " failed");
   if Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Test_Card_Scan;
