##merge analysis
##Do merge analysis for each of the significant QTL, in the widest confidence interval for each locus

#DOWNLOAD THE FILES. DOWNLOADED NOV. 14 2019
#download.file("https://ndownloader.figshare.com/files/18533342", "./data/CCdb/cc_variants.sqlite")
#download.file("https://ndownloader.figshare.com/files/17609252", "./data/CCdb/mouse_genes_mgi.sqlite")
#download.file("https://ndownloader.figshare.com/files/17609261", "./data/CCdb/mouse_genes.sqlite")
#

set.seed(8675309)
library(qtl2)

#load the geno probs
load(file = "./results/Rdata/pr_basic_cleaned.Rdata")
#load the cross file 
load(file = "./results/Rdata/cross_basic_cleaned.Rdata")

#load kinship file. In this case, using LOCO but can use overall file too
load(file = "./results/Rdata/k_loco_basic_cleaned.Rdata") #LOCO
load(file = "./results/Rdata/k_basic_cleaned.Rdata")
#get Xcovar
Xcovar <- get_x_covar(cross_basic)



#create covar object. This is different fron the covar in cross_basic in that sex is a factor (1 for males, 0 for females)
covar = as.matrix(cross_basic$covar)
covar[,"sex"] = (covar[,"sex"] == "M")*1

covar = covar[,-1]#remove sac date as covar for now

covar = apply(covar,2,as.numeric) #make sure all cols are numeric
rownames(covar) = rownames(cross_basic$covar)#make sure rownames match original cross file




##FIX QTL mapping for MAT nonzero vs full
#get qtl list, passed threshold
qtl_norm
#define locus, 1Mbp
chroms = as.vector(unique(qtl_norm$chr)) #chroms
y <- c(1:19, "X","Y","MT")
chroms = chroms[order(match(chroms, y))]



qtl_out = data.frame(matrix(ncol=ncol(qtl_norm)+1))
locus = 1
#for a chromsome, subset qtl
for(i in chroms){
  df = subset(qtl_norm, qtl_norm$chr==i)
  df = df[order(df$pos),]
  
  
  df$locus = NA
  
  while(length(which(is.na(df$locus))) >=1){
    
    idx = which(is.na(df$locus))
    min_pos = min(df$pos[idx])
    df[idx,][which((df$pos[idx] - min_pos) <=1), "locus"] = locus
    locus = locus + 1
  }


  
  colnames(qtl_out) = colnames(df)
  qtl_out = rbind(qtl_out, df)
  
  for(j in 1:nrow(df)){
    x = df[j,]
    xx = df[which((abs(df$pos - df$pos[j])<=1) &(df$locus != df$locus[j]) & (df$pos!= df$pos[j])),]
    x = rbind(x,xx)
    
    if(nrow(x)>1){
      x$locus = locus
      qtl_out = rbind(qtl_out, x)
      locus = locus+1
    }
  }
}

qtl_out = qtl_out[-1,]

#remove singletons
rmv=c()

for(i in 1:nrow(qtl_out)){
  sub = subset(qtl_out, qtl_out$locus == qtl_out$locus[i])
  if(nrow(sub) == 1){
    x = which(qtl_out$chr == qtl_out$chr[i] & qtl_out$pos == qtl_out$pos[i] & qtl_out$lodcolumn == qtl_out$lodcolumn[i] )
    if(length(x) >1){
      print(length(x))
      rmv = c(rmv,i)
    }
  }
  

}
qtl_out = qtl_out[-rmv,]

#remove duplicated loci with different locus id







#qtl_peaks = qtl_peaks_both_norm[which(qtl_peaks_both_norm$lod > qtl_peaks_both_norm$perm_thresh),]
#

merge = list()
query_variants <- create_variant_query_func("./data/CCdb/cc_variants.sqlite")
query_genes <- create_gene_query_func("./data/CCdb/mouse_genes_mgi.sqlite")

for(i in unique(qtl_out$locus)){
  print(i)
  sub = subset(qtl_out, qtl_out$locus == i)
  chr = unique(sub$chr)
  start = min(sub$ci_lo)
  end = max(sub$ci_hi)
  
  variants_locus = query_variants(chr, start, end)
  genes_locus <- query_genes(chr, start, end)
  
  genes_locus = genes_locus[-grep("Gm",genes_locus$Name),]
  
  if("pseudogene" %in% genes_locus$mgi_type){
    genes_locus = genes_locus[-which(genes_locus$mgi_type == "pseudogene"),]
  }
  
  if("miRNA gene" %in% genes_locus$mgi_type){
    genes_locus = genes_locus[-which(genes_locus$mgi_type == "miRNA gene"),]
  }
  
  if("rRNA gene" %in% genes_locus$mgi_type){
    genes_locus = genes_locus[-which(genes_locus$mgi_type == "rRNA gene"),]
  }
  
  
  merge[[i]] = list()
  
  for(j in unique(sub$lodcolumn)){
    print(j)
    out_snps <- scan1snps(pr, cross_basic$pmap, cross_basic$pheno[,j], k_loco[[chr]],  addcovar = covar[,c("sex", "age_at_sac_days","body_weight","generationG24","generationG25","generationG26","generationG27","generationG28","generationG29","generationG30","generationG31","generationG32","generationG33")],
                          query_func=query_variants,chr=chr, start=start, end=end, keep_all_snps=TRUE)
    
    out_name = paste0("./results/plots/merge_analysis/","chr_",chr,"_locus_",i,"_",j,".pdf")
    
    pdf(out_name) 
    
    plot_snpasso(out_snps$lod, out_snps$snpinfo, genes=genes_locus,drop_hilit=1.5)
    
    dev.off() 
    
    
    merge[[i]][[j]] = out_snps
    rm(out_snps)
    gc()
  }
}

plot_snpasso(merge[[1]]$uCT_Ct.TMD$lod, merge[[1]]$uCT_Ct.TMD$snpinfo, genes=genes_locus)

top <- top_snps(out_snps$lod, out_snps$snpinfo)

#out_snps <- scan1snps(pr, cross_basic$pmap, cross_basic$pheno, k_loco[["1"]],  addcovar = covar[,c("sex", "age_at_sac_days","body_weight","generationG24","generationG25","generationG26","generationG27","generationG28","generationG29","generationG30","generationG31","generationG32","generationG33")],
#                      query_func=query_variants,chr=1, start=154.26979, end=158.22213, keep_all_snps=TRUE)

plot_snpasso(out_snps$lod, out_snps$snpinfo)



plot_snpasso(out_snps$lod, out_snps$snpinfo, genes=genes_locus)

top <- top_snps(out_snps$lod, out_snps$snpinfo)
####
####
#plot bv/tv

x = as.data.frame(cross_basic$pheno)
x = x[order(x$uCT_BV.TV),]
x$row  = c(1:nrow(x))

p<-ggplot(data=x, aes(y=uCT_BV.TV, x=row, fill=row)) +geom_bar(stat="identity",width=0.5)+theme_minimal() +xlab("index (n=619)")+ylab("bone volume fraction (BV/TV, %)") + scale_fill_continuous() + theme(legend.position="none")

#bone volume fraction
