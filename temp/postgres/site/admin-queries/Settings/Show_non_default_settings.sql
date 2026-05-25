SELECT
    name,
    setting,
    boot_val AS default_value,
    unit,
    context,
    source
FROM pg_settings
WHERE setting IS DISTINCT FROM boot_val
ORDER BY name;


-- What this shows you

--  * setting → current effective value

--  * boot_val → compiled default

--  * source → where it came from:

--       >  configuration file

--       >  command line

--       >  environment variable

--       >  database

--       >  user

--       >  override

--       >  context → whether it needs reload or restart

-- This is the cleanest “what have we changed from stock?” view.