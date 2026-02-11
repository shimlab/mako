import pandas as pd
import numpy as np
import argparse

from statsmodels.stats.multitest import multipletests

def add_bh_corrected_pvalues(df, pval_col="p_value", alpha=0.05):
    """
    Returns a new DataFrame with an added column for BH-corrected p-values.

    Parameters:
    -----------
    df : pandas.DataFrame
        Original DataFrame containing p-values.
    pval_col : str, default='p_value'
        Name of the column with raw p-values.
    alpha : float, default=0.05
        Significance level for the BH correction (multipletests alpha).

    Returns:
    --------
    df_new : pandas.DataFrame
        Copy of original df with a new column 'bh_corrected_p_value'.
    """
    df_new = df.copy()
    df_new['bh_corrected_p_value'] = np.nan

    non_na_idx = df_new[pval_col].notna()
    if non_na_idx.any():
        _, bh_pvals, _, _ = multipletests(df_new.loc[non_na_idx, pval_col].values,
                                            alpha=alpha, method='fdr_bh')
        df_new.loc[non_na_idx, 'bh_corrected_p_value'] = bh_pvals

    return df_new

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--alpha', type=float, default=0.05, help='Significance level for BH correction')
    parser.add_argument('--output', required=True, help='Output TSV file path')
    parser.add_argument('files', nargs='+', help='Parquet files to concatenate')
    args = parser.parse_args()

    df = (
        pd.concat([pd.read_parquet(f) for f in args.files], ignore_index=True)
        .sort_values(by=["transcript_id", "transcript_position"])
    )

    df = add_bh_corrected_pvalues(df, alpha=args.alpha)

    df.to_csv(args.output, sep="\t", index=False)

if __name__ == "__main__":
    main()