#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo ${BATS_SOURCE}
source ${BATS_TEST_DIRNAME}/../lib/common.sh

TS_NAME=$(basename ${BATS_TEST_FILENAME})

# internal reused testing wrapper over hide_secret() function
function test_hide_secret() {
    local input_str="$1"
    local input_regexp="$2"
    local input_char="$3"
    local exp_ecode="$4"
    local exp_output_str="$5"
    local exp_output_fn=$(mktemp)
    local output_fn=$(mktemp)
    echo -e "${exp_output_str}" > ${exp_output_fn}
    set +e
    echo -e "${input_str}" | hide_secret "${input_regexp}" "${input_char}" > ${output_fn}
    local ecode=$?
    set -e
    local output_fn_str=$(awk '{printf("%s\\n",$0)}' ${output_fn})
    local exp_output_fn_str=$(awk '{printf("%s\\n",$0)}' ${exp_output_fn})
    echo "echo -n '${input_str}' | hide_secret '${input_regexp}' '${input_char}' -> ecode: '${ecode}' stdout: '${output_fn_str}' (exp-ecode: '${exp_ecode}' exp-stdout: '${exp_output_fn_str}')"
    # check exit code
    test "${ecode}" == "${exp_ecode}"
    # check content
    if [ "${exp_output_str}" != "-~skip~-" ]; then
        diff -u ${output_fn} ${exp_output_fn}
    fi
    rm -f ${exp_output_fn} ${output_fn}
}


@test "${TS_NAME}: use-case single-line-part-match-short" {
    test_hide_secret "token: xyz" "token:[ \t]*(.+)" "*" \
      0 "token: ***"
}

@test "${TS_NAME}: use-case single-line-part-match-long" {
    test_hide_secret "token: 1234567890123456789012345678901234567890" "token:[ \t]*(.+)" "_" \
      0 "token: ________________________________________"
}

@test "${TS_NAME}: use-case single-line-while-match" {
    test_hide_secret "token: 1234567890123456789012345678901234567890" "(.+)" "X" \
      0 "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

@test "${TS_NAME}: use-case invalid-regexp" {
    test_hide_secret "token: 1234567890123456789012345678901234567890" ".+" "X" \
      0 "token: 1234567890123456789012345678901234567890"
}

@test "${TS_NAME}: use-case missing-replacement-character-argument" {
    test_hide_secret "token: 1234567890123456789" "token:[ \t]*(.+)" "" \
      0 "token: *******************"
}

@test "${TS_NAME}: use-case missing-regexp-argument" {
    test_hide_secret "token: 1234567890123456789" "" "_" \
      0 "__________________________"
}

@test "${TS_NAME}: use-case missing-all-arguments" {
    test_hide_secret "token: 1234567890123456789" "" "" \
      0 "**************************"
}

# second and every other group is ignored
@test "${TS_NAME}: use-case single-line-regexp-multiple-groups-1" {
    test_hide_secret "token: 1234567890123456789012345678901234567890 " "token:[ \t]*(.+)([ \t]+)" "Y" \
      0 "token: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY "
}

@test "${TS_NAME}: use-case single-line-empty-regexp-group" {
    test_hide_secret "token: " "token:[ \t]*(.*)" "" \
      0 "token: "
}

@test "${TS_NAME}: use-case multi-line-part-match-long" {
    test_hide_secret "A\ntoken: 1234567890123456789012345678901234567890\nB\n" "token:[ \t]*(.+)" "_" \
      0 "A\ntoken: ________________________________________\nB\n"
}

@test "${TS_NAME}: use-case multi-line-full-match-long" {
    test_hide_secret "A\ntoken: 1234567890123456789012345678901234567890\nB\nV\n" "(.+)" "*" \
      0 "*\n***********************************************\n*\n*\n"
}

@test "${TS_NAME}: invalid regexp" {
    test_hide_secret "A\ntoken: 1234567890123456789012345678901234567890\nB\nV\n" "(.+" "" \
      2 "-~skip~-"
}

