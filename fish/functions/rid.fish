function rid --description "Convert between base62 (R...) and base10 report IDs"
    set -l alphabet '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    set -l chars (string split '' -- $alphabet)

    for reportID in $argv
        if test (string sub -l 1 -- $reportID) = R
            # Base62 → Base10
            set -l result 0
            for i in (seq 2 (string length -- $reportID))
                set -l char (string sub -s $i -l 1 -- $reportID)
                set -l val (math --scale=0 (contains -i -- $char $chars)" - 1")
                set result (math --scale=0 "$result * 62 + $val")
            end
            echo $result
        else
            # Base10 → Base62
            set -l num $reportID
            set -l result ''
            while test "$num" -gt 0
                set -l remainder (math --scale=0 "$num % 62")
                set result $chars[(math --scale=0 "$remainder + 1")]$result
                set num (math --scale=0 "floor($num / 62)")
            end
            printf "R%s\n" (string pad -w 11 -c 0 -- $result)
        end
    end
end
