



-- script for call center handson
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US';

CREATE OR REPLACE WAREHOUSE call_center_analytics_wh
    WAREHOUSE_SIZE = 'medium'
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for call center analytics with Cortex LLM';


-- Prepare stages for data, PDFs, and semantic model artifacts.


CREATE DATABASE IF NOT EXISTS call_center_analytics_db;
CREATE SCHEMA IF NOT EXISTS call_center_analytics_db.analytics;
use schema call_center_analytics_db.analytics;

CREATE OR REPLACE STAGE call_center_analytics_db.analytics.audio_files_ja
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for call center audio files';



-- Configure Git integration so we can pull handson assets.
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/snow-jp-handson-org/')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY GIT_INTEGRATION_FOR_HANDSON
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/snow-jp-handson-org/call_center_analytics_handson_for_transportation.git';

list @GIT_INTEGRATION_FOR_HANDSON/branches/main;

COPY FILES INTO @call_center_analytics_db.analytics.audio_files_ja
  FROM @GIT_INTEGRATION_FOR_HANDSON/branches/main/scripts/audio_files/
  PATTERN = '.*\\.mp3$';


CREATE OR REPLACE NOTEBOOK AI_TRANSCRIBE_ANALYTICS_JA_v1
  FROM @GIT_INTEGRATION_FOR_HANDSON/branches/main/notebook
  MAIN_FILE = 'AI_TRANSCRIBE_ANALYTICS_JA_v1.0.ipynb'
  QUERY_WAREHOUSE = call_center_analytics_wh
  WAREHOUSE = SYSTEM$STREAMLIT_NOTEBOOK_WH;


EXECUTE IMMEDIATE FROM
  @GIT_INTEGRATION_FOR_HANDSON/branches/main/setup.sql;
