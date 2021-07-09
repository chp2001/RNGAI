SumCategorySpend = function(self,category,tier)
    local sum=0
    for _,job in self.categoryjobs[category] do
        if job.data.tier==tier then
            sum=sum+job.job.actualSpend
        end
    end
    return sum
end
SumCategoryTarget = function(self,category,tier)
    local sum=0
    for _,job in self.categoryjobs[category] do
        if job.data.tier==tier then
            sum=sum+job.job.targetSpend
        end
    end
    return sum
end
ClearCategoryTarget = function(self,category)
    for _,job in self.categoryjobs[category] do
        job.job.targetSpend=0
    end
end
DoCategoryAllocate = function(self,category,tier,cond,amount)
    local sumpriority=0
    for _,job in self.categoryjobs[category] do
        if job.data.condpriority[cond]>0 then
            sumpriority=sumpriority+job.data.condpriority[cond]
        end
    end
    for _,job in self.categoryjobs[category] do
        if job.data.condpriority[cond]>0 then
            job.job.targetSpend=job.data.condpriority[cond]*amount/sumpriority
        end
    end
end