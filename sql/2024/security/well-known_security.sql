#standardSQL
  # Section: Well-known URIs - securityt.txt
  # Question: What is the prevalence of (signed) /.well-known/security.txt endpoints and prevalence of included attributes (canonical, encryption, expires, policy)?
  # Note: Query is huge (60TB)
  # Note: all_required_exist = contact & expires are mandatory; only_one_requirement_broken = expires & preferred_languages are not allowed to occur multiple times; valid = all_required_exist && !only_one_requirement_broken
  # Note: We do not use status and content-type directly at the moment; Found is true if the final status code after a potential redirection is 200; This has a small number of false positives where sites serve another page (e.g., HTML error page with code 200) at /.well-known/security.txt
  # Note: The custom metric only has an entry for a directive if it is not empty, thus we can assume that a non-null value cannot be an empty list
  # Note: Each directive (except signed) is saved as a list, however currently we do not really check the content
WITH
  security_txt_data AS (
  SELECT
    client,
    page,
    # Bools
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.found'))) AS found,
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.data.redirected'))) AS redirected,
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.data.valid'))) AS valid,
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.data.all_required_exist'))) AS all_required_exist,
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.data.only_one_requirement_broken'))) AS only_one_requirement_broken,
    # Meta Info
    JSON_VALUE(sec_txt, '$.data.status') AS status,
    JSON_VALUE(sec_txt, '$.data.content_type') AS content_type,
    # Directives
    LAX_BOOL(TO_JSON(JSON_VALUE(sec_txt, '$.data.signed'))) AS signed,
    JSON_VALUE_ARRAY(sec_txt, '$.data.contact') AS contact,
    JSON_VALUE_ARRAY(sec_txt, '$.data.expires') AS expires,
    JSON_VALUE_ARRAY(sec_txt, '$.data.encryption') AS encryption,
    JSON_VALUE_ARRAY(sec_txt, '$.data.acknowledgments') AS acknowledgments,
    JSON_VALUE_ARRAY(sec_txt, '$.data.preferred_languages') AS preferred_languages,
    JSON_VALUE_ARRAY(sec_txt, '$.data.canonical') AS canonical,
    JSON_VALUE_ARRAY(sec_txt, '$.data.policy') AS POLICY,
    JSON_VALUE_ARRAY(sec_txt, '$.data.hiring') AS hiring,
    JSON_VALUE_ARRAY(sec_txt, '$.data.csaf') AS csaf,
    # Other has a structure of [("key": value)] and thus needs QUERY_ARRAY
    JSON_QUERY_ARRAY(sec_txt, '$.data.other') AS other
  FROM (
    SELECT
      client,
      page,
      JSON_QUERY(custom_metrics, '$.well-known."/.well-known/security.txt"') AS sec_txt,
    FROM
      `httparchive.all.pages`
    WHERE
      date = '2024-06-01'
      AND is_root_page
      # AND rank <= 10000
    ) 
)


SELECT
  client,
  COUNT(DISTINCT page) AS total_pages,
  # High Level stats
  # Request to .well-known/security.txt failed or did not even start
  COUNTIF(found IS NULL) AS count_failed,
  # Found == final status code is 200
  COUNTIF(found) AS count_security_txt,
  COUNTIF(found) / COUNT(DISTINCT page) AS pct_security_txt,
  # Redirected == response redirected at least once
  COUNTIF(redirected) AS count_redirected_all,
  COUNTIF(redirected) / COUNT(DISTINCT page) AS pct_redirected_all,
  # Redirected found == response redirected and final status code is 200 (some redirect and then answer with 500 or 426; Note that some also use a redirect status code such as 307 but as there is no location header, do not actually redirect)
  COUNTIF(redirected AND found) AS count_redirected_found,
  # Redirected valid == response redirected, final status code is 200 and file is a "valid" security.txt file
  COUNTIF(redirected AND valid) AS count_redirected_valid,
  # Valid == all_required_exist && !only_one_requirement_broken
  COUNTIF(valid) AS count_valid,
  COUNTIF(valid) / COUNTIF(found) AS pct_valid,
  # All required exist == expires && contact
  COUNTIF(all_required_exist) AS count_all_required_exist,
  COUNTIF(all_required_exist) / COUNTIF(found) AS pct_all_required_exist,
  # Only one requriement broken == expires & preferred_languages are not allowed to occur multiple times
  COUNTIF(only_one_requirement_broken) AS count_only_one_requirement_broken,
  COUNTIF(only_one_requirement_broken) / COUNTIF(found) AS pct_only_one_requirement_broken,
  # Individual values
  COUNTIF(signed) AS count_signed,
  COUNTIF(signed) / COUNTIF(found) AS pct_signed,
  COUNTIF(contact IS NOT NULL) AS contact,
  COUNTIF(contact IS NOT NULL) / COUNTIF(found) AS pct_contact,
  COUNTIF(expires IS NOT NULL) AS expires,
  COUNTIF(expires IS NOT NULL) / COUNTIF(found) AS pct_expires,
  COUNTIF(encryption IS NOT NULL) AS encryption,
  COUNTIF(encryption IS NOT NULL) / COUNTIF(found) AS pct_encryption,
  COUNTIF(acknowledgments IS NOT NULL) AS acknowlegments,
  COUNTIF(acknowledgments IS NOT NULL) / COUNTIF(found) AS pct_acknowledgments,
  COUNTIF(preferred_languages IS NOT NULL) AS preferred_languages,
  COUNTIF(preferred_languages IS NOT NULL) / COUNTIF(found) AS pct_preferred_languages,
  COUNTIF(canonical IS NOT NULL) AS canonical,
  COUNTIF(canonical IS NOT NULL) / COUNTIF(found) AS pct_canonical,
  COUNTIF(POLICY IS NOT NULL) AS POLICY,
  COUNTIF(POLICY IS NOT NULL) / COUNTIF(found) AS pct_policy,
  COUNTIF(hiring IS NOT NULL) AS hiring,
  COUNTIF(hiring IS NOT NULL) / COUNTIF(found) AS pct_hiring,
  COUNTIF(csaf IS NOT NULL) AS csaf,
  COUNTIF(csaf IS NOT NULL) / COUNTIF(found) AS pct_csaf,
  COUNTIF(other IS NOT NULL) AS other,
  COUNTIF(other IS NOT NULL) / COUNTIF(found) AS pct_other,
  # Other values relative to only valid files (as other can be garbage if the file is not actually a security.txt file)
  COUNTIF(other IS NOT NULL
    AND valid ) AS other_valid,
  COUNTIF(other IS NOT NULL
    AND valid ) / COUNTIF(valid ) AS pct_other_valid,
  # Average counts of directives (only non-null values are counted; i.e., min is 1, might be better to count the average of all "found" files, i.e., including 0)
  AVG(ARRAY_LENGTH(contact)) as avg_contact_count,
  AVG(ARRAY_LENGTH(expires)) as avg_expires_count,
  AVG(ARRAY_LENGTH(encryption)) as avg_encryption_count,
  AVG(ARRAY_LENGTH(acknowledgments)) as avg_acknowledgments_count,
  AVG(ARRAY_LENGTH(preferred_languages)) as avg_preferred_language_count,
  AVG(ARRAY_LENGTH(canonical)) as avg_canonical_count,
  AVG(ARRAY_LENGTH(policy)) as avg_policy_count,
  AVG(ARRAY_LENGTH(hiring)) as avg_hiring_count,
  AVG(ARRAY_LENGTH(csaf)) as avg_csaf_count,
  AVG(ARRAY_LENGTH(other)) as avg_other_count
FROM security_txt_data
# TODO: maybe add WHERE STARTS_WITH(content_type, 'text/plain') and get the totals from another WITH statement + join
GROUP BY
  client

/*
# Quite some pages do not have any security.txt data, i.e., the custom metric collection (for well-know) failed; more info could be in the "error" and "message"
SELECT
  redirected,
  found,
  COUNT(0) as ct
FROM
  security_txt_data
GROUP BY
  redirected,
  found
ORDER BY
  ct DESC
*/

/*
# Most status codes are 404, however, 403 or 503 also exist
# Some sites also use a redirect status code without a location header (no redirect occurs!)
SELECT
  status,
  redirected,
  found,
  COUNT(0) as ct
FROM
  security_txt_data
GROUP BY
  status,
  redirected,
  found
ORDER BY
  ct DESC
*/

/*
# Most found/valid files use content-type text/plain.* Maybe we can use a filter on the content-type to remove all other files (e.g., HTML files with status code 200 at /.well-known/security.txt)
# Responses without any content-type are quite rare
SELECT
  content_type,
  found,
  valid,
  COUNT(0) as ct
FROM
  security_txt_data
GROUP BY
  content_type,
  found,
  valid
ORDER BY
  ct DESC
*/

/*
# Do any of the non text/plain files have anything resembling a security.text file at all?
# They only have "other" values that appear to be mostly css that we accidentally match as they return status code 200 at /.well-known/security.txt
SELECT
  content_type as ct,
  COUNT(page) as total,
  COUNTIF(signed) as signed,
  COUNTIF(contact IS NOT NULL) as contact,
  COUNTIF(expires IS NOT NULL) as expires,
  COUNTIF(encryption IS NOT NULL) as encryption,
  COUNTIF(acknowledgments IS NOT NULL) as ack,
  COUNTIF(preferred_languages IS NOT NULL) as pref_lang,
  COUNTIF(canonical IS NOT NULL) as canonical,
  COUNTIF(POLICY IS NOT NULL) as policy,
  COUNTIF(hiring IS NOT NULL) as hiring,
  COUNTIF(csaf IS NOT NULL) as csaf,
  COUNTIF(other IS NOT NULL) as other
FROM
  security_txt_data
WHERE
  found
  AND NOT STARTS_WITH(content_type, "text/plain")
GROUP BY
  ct
*/

/*
# Valid (other) values seem very rare for non text/plain responses!
# For text/plain they see to be Acknowledgements (typo/AE vs BE), Info, Tips, Hash, ...
SELECT
  contact,
  expires,
  preferred_languages,
  other
FROM
  security_txt_data
WHERE
  found
  AND other is not NULL
  #AND STARTS_WITH(content_type, "text/html;charset=utf-8")
  #AND NOT STARTS_WITH(content_type, "text/plain")
  AND STARTS_WITH(content_type, "text/plain")
*/

/*
# Value distribution of other values!
# Common values (only text/plain otherwise it will be HTML stuff): Acknowledgements, Hash, OpenBugBounty, Responsible Disclosure Program, Tips, Signature, Info
SELECT
  JSON_VALUE_ARRAY(other_val)[offset(0)] as directive_name,
  COUNT(0) as cnt
FROM
  security_txt_data,
  UNNEST(other) as other_val
WHERE
  found
  AND other IS NOT NULL
  AND STARTS_WITH(content_type, "text/plain")
GROUP BY
  directive_name
ORDER BY
  cnt DESC
*/


