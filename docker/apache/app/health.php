<?php
/**
 * Health check para Docker
 */
http_response_code(200);
header('Content-Type: text/plain');
echo "OK";
?>
