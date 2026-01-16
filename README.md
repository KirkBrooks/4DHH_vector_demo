# 4D Happy Hour Vector Demo

This project is a demonstartion of a couple of things. First, it's showing some ideas for importing large datafiles into 4D. In this case they are some public files of Amazong products and reviews. The files are available at: 

https://mcauleylab.ucsd.edu/public_datasets/data/amazon_2023/raw/review_categories/Electronics.jsonl.gz
https://mcauleylab.ucsd.edu/public_datasets/data/amazon_2023/raw/meta_categories/meta_Electronics.jsonl.gz

## Importing Large Files

Working with large files, especially over about 2 gigs, is challenging. Under 2 gigs 4D can hold it all in memory. Over that you have to have some other stategy. In this example I went back to [SET CHANNEL](https://developer.4d.com/docs/commands/set-channel). This allows you to open large files without loading it in memory. 
