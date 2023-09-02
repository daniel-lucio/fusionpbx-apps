<?php
//validate and format limit and offset clause of select statement
        if (!function_exists('limit_offset')) {
                function limit_offset($limit, $offset = 0) {
                        $regex = '#[^0-9]#';
                        $limit = preg_replace($regex, '', $limit);
                        $offset = preg_replace($regex, '', $offset);
                        if (is_numeric($limit) && $limit > 0) {
                                $clause = ' limit '.$limit;
                                $offset = is_numeric($offset) ? $offset : 0;
                                $clause .= ' offset '.$offset;
                        }
                        return $clause.' ';
                }
        }
