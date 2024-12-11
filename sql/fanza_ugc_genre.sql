DECLARE
execlusion_genre_category ARRAY<string> DEFAULT ['----',
  'キャンペーン'];
  -- 除外ジャンル正規表現
DECLARE
execlusion_genre_regexp string DEFAULT '(以上作品|ハイビジョン|セール|sale|OFF|ヒット|キャンペーン|8K|4K)';
DECLARE
today_dt DATE DEFAULT CURRENT_DATE('Asia/Tokyo');
DECLARE
base_dt DATE DEFAULT DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL 2 DAY);
INSERT INTO
    `columbus-rc-dev.rcdev_columbus_tmp.genre_genre_video`
WITH
    content_keywords AS (
        SELECT
            i3s.content,
            SPLIT(article, ":")[
                OFFSET
                (0)] AS k,
            SPLIT(article, ":")[
                OFFSET
                (1)] AS v,
            i3s.title,
            i3s.comment,
            i3s.series,
            ARRAY_TO_STRING(i3s.keywords, "") AS keywords
        FROM
            `columbus-rc-dev.rcdev_columbus_tmp.i3s_exist_sample_video` i3s,
            UNNEST(i3s.article) AS article
                JOIN
            `dmm-group-data-infrastructure.common_content.digital_content` digc
            ON
                digc.content_id = i3s.content
        WHERE
            floor IN ('digital_videoa',
                      'digital_videoc')
          AND i3s.dt = base_dt
        ORDER BY
            i3s.rank ASC ),
    only_content_keyword AS (
        SELECT
            content,
            v AS keyword_id,
            title,
            comment,
            series
        FROM
            content_keywords
        WHERE
            k = "keyword" ),
    filtered_keywords AS (
        SELECT
            k.keyword_id,
            k.keyword,
            k.category,
            REGEXP_CONTAINS(k.keyword, execlusion_genre_regexp) AS is_excluded
        FROM
            `dmm-group-data-infrastructure.common_content.keyword` k ),
    genre_keywords AS (
        SELECT
            DISTINCT k.keyword_id,
                     k.keyword,
                     ock.content,
                     ock.title,
                     ock.comment,
                     ock.series
        FROM
            only_content_keyword ock
                INNER JOIN
            filtered_keywords k
            ON
                CAST(k.keyword_id AS STRING) = ock.keyword_id ),
    execlusion_genre AS (
        SELECT
            keyword_id
        FROM
            filtered_keywords
        WHERE
            is_excluded
           OR category IN UNNEST(execlusion_genre_category) ),
    unique_genre_keywords AS (
SELECT
    DISTINCT keyword_id,
    keyword
FROM
    genre_keywords
WHERE
    keyword_id NOT IN (
    SELECT
    keyword_id
    FROM
    execlusion_genre) ),
    new_genre AS (
SELECT
    genre_id AS keyword_id,
    name AS keyword,
FROM
    `columbus-rc-dev.rcdev_columbus_tmp.genre_addon`
WHERE
    type = 'ugc' ),
    keyword_combinations AS (
SELECT
    g1.keyword_id AS first_keyword_id,
    g1.keyword AS first_keyword,
    g2.keyword_id AS second_keyword_id,
    g2.keyword AS second_keyword,
FROM
    unique_genre_keywords g1
    CROSS JOIN
    new_genre g2 ),
    target_content AS (
SELECT
    gk.keyword AS first_keyword,
    gk.keyword_id AS first_keyword_id,
    ng.keyword AS second_keyword,
    ng.keyword_id AS second_keyword_id,
    gk.content,
    gk.title,
    gk.comment,
    gk.series,
FROM
    genre_keywords gk
    JOIN
    new_genre ng
ON
    (gk.title LIKE CONCAT('%',ng.keyword,'%')
    OR gk.comment LIKE CONCAT('%',ng.keyword,'%')
    OR gk.series LIKE CONCAT('%',ng.keyword,'%') ) ),
    keyword_keyword AS (
SELECT
    tc.content,
    kc.first_keyword_id,
    kc.first_keyword,
    kc.second_keyword_id,
    kc.second_keyword
FROM
    target_content tc
    JOIN
    keyword_combinations kc
ON
    (tc.first_keyword_id = kc.first_keyword_id
    AND tc.second_keyword_id = kc.second_keyword_id) ),
    final_result AS (
SELECT
    CAST(first_keyword_id AS STRING) AS first_keyword_id,
    second_keyword_id,
    COUNT(DISTINCT content) AS product_num,
    today_dt AS dt
FROM
    keyword_keyword
GROUP BY
    first_keyword_id,
    second_keyword_id
HAVING
    COUNT(DISTINCT content) > 1 )
SELECT
    first_keyword_id,
    second_keyword_id,
    product_num,
    dt
FROM
    final_result;