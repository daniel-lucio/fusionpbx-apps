<?php
if (!function_exists('version')) {
        function version() {
                // print 'version() is deprecated, use software::version() instead';
                        return software::version();
                }
        }

if (!function_exists('numeric_version')) {
        function numeric_version() {
                // print 'numeric_version() is deprecated, use software::numeric_version() instead';
                return software::numeric_version();
        }
}
