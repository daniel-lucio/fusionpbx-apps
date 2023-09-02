//validate and format order by clause of select statement
        if (!function_exists('order_by')) {
                function order_by($col, $dir, $col_default = '', $dir_default = 'asc') {
                        $order_by = ' order by ';
                        $col = preg_replace('#[^a-zA-Z0-9-_.]#', '', $col);
                        $dir = strtolower($dir) == 'desc' ? 'desc' : 'asc';
                        if ($col != '') {
                                return $order_by.$col.' '.$dir.' ';
                        }
                        else if (is_array($col_default) || $col_default != '') {
                                if (is_array($col_default) && @sizeof($col_default) != 0) {
                                        foreach ($col_default as $k => $column) {
                                                $direction = (is_array($dir_default) && @sizeof($dir_default) != 0 && (strtolower($dir_default[$k]) == 'asc' || strtolower($dir_default[$k]) == 'desc')) ? $dir_default[$k] : 'asc';
                                                $order_bys[] = $column.' '.$direction.' ';
                                        }
                                        if (is_array($order_bys) && @sizeof($order_bys) != 0) {
                                                return $order_by.implode(', ', $order_bys);
                                        }
                                }
                                else {
                                        return $order_by.$col_default.' '.$dir_default.' ';
                                }
                        }
                }
        }
