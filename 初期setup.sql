-- script for call center handson
USE ROLE ACCOUNTADMIN;

-- cross region call
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US';

-- Prepare warehouse
-- for voc
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'SMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for VOC analyze with Cortex LLM';


-- Create voc snowflake object
CREATE OR REPLACE DATABASE VOC_ANALYZE;
CREATE OR REPLACE SCHEMA AIRLINE_SURVEY;
use schema VOC_ANALYZE.AIRLINE_SURVEY;

CREATE OR REPLACE STAGE VOC_ANALYZE.AIRLINE_SURVEY.HANDSON_RESOURCES
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for VOC HandsOn';


-- Prepare voc resources
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/snow-jp-handson-org/')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY GIT_INTEGRATION_FOR_VOC_ANALYZE_HANDSON
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/snow-jp-handson-org/voc_analyze_for_airline.git';

list @GIT_INTEGRATION_FOR_VOC_ANALYZE_HANDSON/branches/main;

COPY FILES INTO @VOC_ANALYZE.AIRLINE_SURVEY.HANDSON_RESOURCES/Data/
  FROM @GIT_INTEGRATION_FOR_VOC_ANALYZE_HANDSON/branches/main/Data/
  PATTERN = '.*\\.csv.gz$';

-- Create HandsOn Objects 
CREATE OR REPLACE TABLE VOC_ANALYZE.AIRLINE_SURVEY.SURVEYS (
  SURVEY_ID         NUMBER(38,0) IDENTITY(1,1) PRIMARY KEY COMMENT '内部サロゲートキー',
  FREE_TEXT_COMMENT VARCHAR                         COMMENT '自由記述'
)
COMMENT = '搭乗アンケート';

CREATE OR REPLACE TABLE VOC_ANALYZE.AIRLINE_SURVEY.CA_INSIGHT_2025_10 (
	DEPARTURE_DATE DATE,
	INSIGHT VARCHAR(16777216)
)
COMMENT = '10月の客室乗務員へのネガティブフィードバック要約';

COPY INTO VOC_ANALYZE.AIRLINE_SURVEY.SURVEYS
FROM '@VOC_ANALYZE.AIRLINE_SURVEY.HANDSON_RESOURCES/Data/surveys.csv.gz'
FILE_FORMAT = (
  TYPE = CSV
  COMPRESSION = GZIP
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
)
ON_ERROR = 'CONTINUE';

COPY INTO VOC_ANALYZE.AIRLINE_SURVEY.CA_INSIGHT_2025_10
FROM '@VOC_ANALYZE.AIRLINE_SURVEY.HANDSON_RESOURCES/Data/ca_insight_2025_10.csv.gz'
FILE_FORMAT = (
  TYPE = CSV
  COMPRESSION = GZIP
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
)
ON_ERROR = 'CONTINUE';

CREATE OR REPLACE NOTEBOOK VOC_ANALYZE_for_Airline
  FROM @GIT_INTEGRATION_FOR_VOC_ANALYZE_HANDSON/branches/main/Notebook
  MAIN_FILE = 'AI SQL for Airline.ipynb'
  QUERY_WAREHOUSE = COMPUTE_WH
  WAREHOUSE = SYSTEM$STREAMLIT_NOTEBOOK_WH;


-- Prepare warehouse
-- for call center
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
