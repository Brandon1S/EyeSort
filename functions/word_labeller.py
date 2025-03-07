import pandas as pd
import json
import ast


# We used precise word region
# sentence: I did not go to school and stayed home.
# Beginning (region 1): I did not
# Pretarget (region 2): go to
# Target    (region 3): school
# Ending    (region 4): and stayed home.
#
# Now, to be more precise, we can split the regions and give each word a number
# 1.1   I
# 1.2   did
# 1.3   not
# 2.1   go
# ....
# 4.3   home.
#
# Notice, we didn't use 1.0 or 4.0 to avoid confusion.


# Change the filename and make sure the script and the data file are in the same directory
FILENAME = "RLGL_FR_reg2.xlsx"


RLGL = pd.read_excel(FILENAME)
# all in pixels
# offset from the left edge of the screen of where the sentence begins
Offset = 281
# number of pixels per character. This will vary depending on the font type and size.
PPC = 14
# Y dimension of the top of the IAs
Y_Pix = 514
# the height of your IAs
Height = 76


def fill_word_labels(row):
    """ "
    reads beginning, pretarget, target_word, and ending columns
    calculates the x-coordinate positions for each word in the sentence
    saves the result in a dictionary in this format:
    {
        "1.1": (190, 200),
        "1.2": (200, 250),
        ....
    }
    """
    word_labels = {}
    last_word_ending_pos = Offset
    odd_space = 0

    def word_labeller(region, region_sentence):
        nonlocal last_word_ending_pos
        nonlocal odd_space
        words = str(region_sentence).split()
        for index, word in enumerate(words, start=1):
            key = f"{region}.{index}"
            start = last_word_ending_pos
            end = start + PPC * (len(word) + odd_space)
            last_word_ending_pos = end
            word_labels[key] = (start, end)
            odd_space = 1

    word_labeller(1, row["beginning"])
    word_labeller(2, row["pretarget"])
    word_labeller(3, row["target_word"])
    word_labeller(4, row["ending"])
    return json.dumps(word_labels)


def find_interest_area(positions, fixation):
    """
    Read word positions dictionary.
    Check the given fixation and find which range it falls into.
    E.g.    fixation is 300 and dictionary is {"1.1": [281, 290], "1.2": (290, 300]}
            returns "1.2" as precise region label
    Note:   if fixation is lower than 1.1, return "left"
            if fixation is higher than last word, return "right"
    """
    if fixation == ".":
        return fixation
    word_positions = ast.literal_eval(positions)
    for key, (x_min, x_max) in word_positions.items():
        if x_min < fixation <= x_max:
            return key
    all_values = [value for tup in word_positions.values() for value in tup]
    if fixation == min(all_values):
        return "1.1"
    elif fixation < min(all_values):
        return "left"
    elif fixation > max(all_values):
        return "right"
    return None


def main():
    # find x-coordinates for all words
    RLGL["WordPositions"] = RLGL.apply(fill_word_labels, axis=1)
    # update current fix column with precise region label
    RLGL["CURRENT_FIX_INTEREST_AREA_ID"] = RLGL.apply(
        lambda row: find_interest_area(row["WordPositions"], row["CURRENT_FIX_X"]),
        axis=1,
    )
    # update next fix column with precise region label
    RLGL["NEXT_FIX_INTEREST_AREA_ID"] = RLGL.apply(
        lambda row: find_interest_area(row["WordPositions"], row["NEXT_FIX_X"]), axis=1
    )
    # save the output in tsv format. Can be opened in excel by setting delimiter to be a tab
    output_filename = ".".join(FILENAME.split(".")[:-1]) + "_With_IA.tsv"
    RLGL.to_csv(output_filename, sep="\t", index=False)


main()