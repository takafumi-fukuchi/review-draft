-- 新ジャンル×新ジャンルのSQL
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
            i3s.title,
            i3s.comment,
            i3s.series,
        FROM
            `columbus-rc-dev.rcdev_columbus_tmp.i3s_exist_sample_video` i3s
        WHERE
            floor IN ('digital_videoa',
                      'digital_videoc')
          AND i3s.dt = base_dt
        ORDER BY
            i3s.rank ASC ),
    new_genre AS (
        SELECT
            genre_id AS keyword_id,
            name AS keyword,
        FROM
            `columbus-rc-dev.rcdev_columbus_tmp.genre_addon`
        WHERE type = 'ugc'
    ),
    with_new_genre AS (
        SELECT
            content,
            title,
            comment,
            series,
            keyword,
            keyword_id
        FROM
            content_keywords AS si
                JOIN
            new_genre AS mg
            ON
                (si.title LIKE CONCAT('%',mg.keyword,'%')
                    OR si.comment LIKE CONCAT('%',mg.keyword,'%')
                    OR si.series LIKE CONCAT('%',mg.keyword,'%') )),
    keyword_combinations AS (
        SELECT
            g1.keyword_id AS first_keyword_id,
            g1.keyword AS first_keyword,
            g2.keyword_id AS second_keyword_id,
            g2.keyword AS second_keyword
        FROM
            new_genre g1
                CROSS JOIN
            new_genre g2
        WHERE
            g1.keyword_id < g2.keyword_id -- 同じキーワードペアを重複させない条件
    ),
    new_genre_cross_new_genre AS (
        SELECT
            content,
            kc.first_keyword_id,
            kc.first_keyword,
            kc.second_keyword_id,
            kc.second_keyword
        FROM
            with_new_genre AS ng
                JOIN
            keyword_combinations AS kc
            ON
                ( ng.keyword_id = kc.first_keyword_id AND (ng.title LIKE CONCAT('%',kc.second_keyword,'%')
                    OR ng.comment LIKE CONCAT('%',kc.second_keyword,'%')
                    OR ng.series LIKE CONCAT('%',kc.second_keyword,'%')))),
    final_result AS (
        SELECT
            tc.first_keyword_id,
            tc.first_keyword,
            tc.second_keyword_id,
            tc.second_keyword,
            COUNT(tc.content) AS product_num
        FROM
            new_genre_cross_new_genre AS tc
        GROUP BY
            tc.first_keyword_id,
            tc.first_keyword,
            tc.second_keyword_id,
            tc.second_keyword
        HAVING
            product_num > 1 )
SELECT
    first_keyword_id,
    second_keyword_id,
    product_num,
    today_dt AS dt
FROM
    final_result;