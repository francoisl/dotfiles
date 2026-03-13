function rid --description "Convert base62 report ID (R...) to base 10"
    set -l reportID $argv[1]

    if test (string sub -l 1 -- $reportID) != R
        echo $reportID
        return
    end

    set -l chars (string split '' -- '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    set -l result 0

    for i in (seq 2 (string length -- $reportID))
        set -l char (string sub -s $i -l 1 -- $reportID)
        set -l val (math (contains -i -- $char $chars)" - 1")
        set result (math "$result * 62 + $val")
    end

    printf "%.0f\n" $result
end
