-- 既存ジャンル×既存ジャンルのSQL
DECLARE
base_dt DATE DEFAULT DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL 2 DAY);
  -- beginなどの範囲は当日でいいため指定
DECLARE
today_dt DATE DEFAULT CURRENT_DATE('Asia/Tokyo');
  -- 冪等にするためデータを削除
  -- 除外ジャンルのカテゴリ
DECLARE
execlusion_genre_category ARRAY<string> DEFAULT ['----',
  'キャンペーン'];
  -- 除外ジャンル正規表現
DECLARE
execlusion_genre_regexp string DEFAULT '(以上作品|ハイビジョン|セール|sale|OFF|ヒット|キャンペーン|8K|4K)';
INSERT INTO
    `columbus-rc-dev.rcdev_columbus_tmp.genre_genre_video`
WITH consts AS (
    SELECT CURRENT_DATE('Asia/Tokyo') - 2 AS base_dt
    ),
    content_keywords AS (
SELECT
    i3s.content,
    SPLIT(article, ":")[OFFSET(0)] AS k,
    SPLIT(article, ":")[OFFSET(1)] AS v,
    i3s.title,
    i3s.comment,
    i3s.series,
    ARRAY_TO_STRING(i3s.keywords, "") AS keywords
FROM
    consts,
    `columbus-rc-dev.rcdev_columbus_tmp.i3s_exist_sample_video` i3s,
    UNNEST(i3s.article) AS article
    JOIN
    `dmm-group-data-infrastructure.common_content.digital_content` digc ON digc.content_id = i3s.content
WHERE
    floor IN ('digital_videoa', 'digital_videoc')
  AND
    i3s.dt = base_dt
ORDER BY
    i3s.rank ASC
    ),
    only_content_keyword AS (
SELECT
    content,
    v AS keyword_id
FROM
    content_keywords
WHERE
    k = "keyword"
    ),
    filtered_keywords AS (
SELECT
    k.keyword_id,
    k.keyword,
    k.category,
    REGEXP_CONTAINS(k.keyword, execlusion_genre_regexp) AS is_excluded
FROM
    `dmm-group-data-infrastructure.common_content.keyword` k
    ),
    genre_keywords AS (
SELECT DISTINCT
    k.keyword_id,
    k.keyword,
    ock.content
FROM
    only_content_keyword ock
    INNER JOIN
    filtered_keywords k
ON CAST(k.keyword_id AS STRING) = ock.keyword_id
    ),
    execlusion_genre AS (
SELECT
    keyword_id
FROM
    filtered_keywords
WHERE
    is_excluded OR category IN UNNEST(execlusion_genre_category)
    ),
    unique_genre_keywords AS (
SELECT DISTINCT keyword_id, keyword
FROM genre_keywords
WHERE keyword_id NOT IN (SELECT keyword_id FROM execlusion_genre)
    ),
    keyword_combinations AS (
SELECT
    g1.keyword_id AS first_keyword_id,
    g1.keyword AS first_keyword,
    g2.keyword_id AS second_keyword_id,
    g2.keyword AS second_keyword
FROM
    unique_genre_keywords g1
    CROSS JOIN
    unique_genre_keywords g2
WHERE
    g1.keyword_id < g2.keyword_id -- 同じキーワードペアを重複させない条件
    ),
    keyword_keyword AS (
SELECT
    gk.content,
    kc.first_keyword_id,
    kc.first_keyword,
    kc.second_keyword_id,
    kc.second_keyword
FROM
    genre_keywords gk
    JOIN
    keyword_combinations kc
ON gk.keyword_id IN (kc.first_keyword_id, kc.second_keyword_id)
    ),
    final_result AS (
SELECT
    CAST(first_keyword_id AS STRING) AS first_keyword_id,
    CAST(second_keyword_id AS STRING) AS second_keyword_id,
    COUNT(DISTINCT content) AS product_num,
    today_dt AS dt
FROM
    keyword_keyword
GROUP BY
    first_keyword_id, second_keyword_id
HAVING COUNT(DISTINCT content) > 1
    )
SELECT *
FROM final_result;
