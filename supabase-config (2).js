/**
 * การตั้งค่าเชื่อมต่อฐานข้อมูลกลาง Supabase (สำหรับ GitHub Pages)
 * ระบบออกใบเสร็จรับเงิน มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ
 */
(function () {
  const DEFAULT_SUPABASE_URL = "https://tiyfzpsmuapzeyqlqbwp.supabase.co";
  const DEFAULT_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpeWZ6cHNtdWFwemV5cWxxYndwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwNDUyNjAsImV4cCI6MjEwNzYyMTI2MH0.f5YPmaWsBPu75KcXo7ZCPUcX0agmfUwxEfouNjzfw6A";

  let storedUrl = "";
  let storedKey = "";
  try {
    storedUrl = window.localStorage.getItem("rmutsb_supabase_url") || "";
    storedKey = window.localStorage.getItem("rmutsb_supabase_anon_key") || "";
  } catch (e) {}

  window.RMUTSB_SUPABASE_CONFIG = {
    url: (storedUrl || DEFAULT_SUPABASE_URL).trim().replace(//+$/, ""),
    anonKey: (storedKey || DEFAULT_SUPABASE_ANON_KEY).trim(),
    pollingIntervalMs: 3000,
    isConfigured: function () {
      return Boolean(this.url && this.anonKey && this.url.startsWith("http"));
    },
    saveConfig: function (newUrl, newAnonKey) {
      const cleanUrl = (newUrl || "").trim().replace(//+$/, "");
      const cleanKey = (newAnonKey || "").trim();
      this.url = cleanUrl;
      this.anonKey = cleanKey;
      try {
        window.localStorage.setItem("rmutsb_supabase_url", cleanUrl);
        window.localStorage.setItem("rmutsb_supabase_anon_key", cleanKey);
      } catch (e) {}
    },
    clearConfig: function () {
      try {
        window.localStorage.removeItem("rmutsb_supabase_url");
        window.localStorage.removeItem("rmutsb_supabase_anon_key");
      } catch (e) {}
      this.url = DEFAULT_SUPABASE_URL;
      this.anonKey = DEFAULT_SUPABASE_ANON_KEY;
    }
  };
})();
