---
layout: post
title:  "Accenture Replaces VMware VDI with Azure, Scripts and DevOps Practices"
author: "Dan Stolts"
author-link: "@itproguru"
author-image: "/images/authors/DanStolts.jpg"
date:   2016-02-17
categories: [DevOps]
color: "blue"
#image: "{{ site.baseurl }}/images/imagename.png" #should be ~350px tall
excerpt: Add a short description of what this article is about, helping a fellow developer understand why they would want to read it. What value will they get out of reading it? Focus on the problem or technologies and let that be the guiding light.
language: The language of the article (e.g.: [English])
verticals: The vertical markets this article has focus on (e.g.: [Energy, Manufacturing & Resources, Financial Services, Public Sector, “Retail, Consumer Products & Services”, Environmental, Communications/Media, Transportation & Logistics, Smart Cities, Agricultural, Environmental, Healthcare, Other])
---

Begin with an intro statement with the following details:

- Solution overview
- Key technologies used
- Core Team: Names, roles and Twitter handles 

 
## Customer profile ##

Profile: Accenture Life Insurance & Annuity is part of Accenture Financial Services, the industry arm of Accenture. Accenture Life Insurance develops ALIP (Accenture Life Insurance & Annuity Platform), which helps insurers reduce operating costs, manage risk and drive growth through improved product development and distribution, policy administration, and technology platform consolidation and modernization. ALIP is used by more than 40 leading insurers and distributors. The platform can be implemented as a full suite to address all steps in the policy lifecycle or carriers can implement standalone components such as electronic applications, underwriting, policy administration and payout administration. They are focused primarily on the US & Canadian markets (T1 through T3 insurers) but can support customers globally

Accenture ALIP: Kym Gully - Organizer and Executive Sponsor

Microsoft: Dan Stolts - Project Owner, Project Manager, Dev Lead, Primary Developer, Architect 
Microsoft: Andrew Ri



This section will contain general information about the customer, including the following:

- Company name and URL
- Company description
- Company location
- What are their product/service offerings?
 
## Problem statement ##
 
*If you’d really like to make your write-up pop, include a customer quote that highlights the customer’s problem(s)/challenges. Attribute all quotes with Name, Title, Company.*
 
From new business and policy administration to payout and claims, carriers using ALIP require accelerated product introduction and exceptional processing speeds. ALIP is looking for a solution that can provide these coupled with the agility, scalability, productivity and possible cost savings of migrating to a cloud environment. They would also like to pursue IaaS solutions to help insurers avoid the high cost of acquiring and maintaining infrastructure, and in conjunction, implement an on-demand, consumption-based pricing model, allowing carriers to easily scale up or down in order to more cost effectively manage peak demand or test new products before launching in the market.

By implementing an Azure based technology infrastructure, ALIP offers carriers a way to lower costs and simplify their IT environment while providing them the ability to maintain their unique product and service differentiation with the highly 
configurable and robust features of ALIP. Recent benchmarking tests with Accenture conducted in a real-world setting exceeded their performance expectations and confirmed scalability potential. Microsoft Azure offerings will deliver new levels of business agility for ALIP and aligns with Accenture’s ‘Cloud First’ agenda.

Microsoft will host a workshop to foster understanding of Microsoft Azure offerings. This will take the form of a 3 to 4-day Architectural Design Session & White Boarding with an aim to: 
-	Complete a Value Stream Analysis which includes understanding lead time, waste time and processing time of each step of the application pipeline.
-	Generate a plan for moving to an Azure based development and test environment with some or many of the gaps and wastes closed.
-	Improve understanding of how their needs map to the cloud migration
-	Identify the best technologies to deploy for various workloads. 



## Solution, steps, and delivery ##
The next step is to hold a Hackathon to dive into the various migrations that need to happen, with a primary focus on converting IaaS workloads (Linux machines) to Azure as either Linux VMs or Docker Containers running on Linux. By the end of the Hackathon, the goal is to have successfully migrated one application and have a clear path for the customer to continue the remaining application migrations. Additional support will be provided over several weeks via email and phone to answer questions as they dive into the plan. Two additional workshop days will be scheduled as needed to teach deeper technical skills on technologies being leveraged for the migration.


The majority of your win artifacts will be included in this section, including (but not limited to) the following: Pictures, drawings, value stream mappings, architectural diagrams and demo videos.

This section should include the following details:

- Value Stream Mapping description and how it helped in the exercise.

- Technical details of how this was implemented.

- What was worked on and what problem it helped solve.

- DevOps practice area improved.

- Pointers to references or documentation.
 
- Learnings from the Microsoft team and the customer team.


*If you’d really like to make your write-up pop, include a customer quote that highlights the solution. Attribute all quotes with Name, Title, Company.*

**Directions for adding images:**

1. Create a folder for your project images in the “images” folder in the GitHub repo files. This is where you will add all of the images associated with your write-up.
 
2. Add links to your images using the following absolute path:

  `![Description of the image]({{site.baseurl}}/images/projectname/myimage.png)`

  Here’s an example: 

  `![Value Stream Mapping]({{site.baseurl}}/images/orckestra/orckestra2.jpg)`

3. Note that capitalization of the file name and the file extension must match exactly for the images to render properly.


## Azure Automation Scripts
Creating an Azure Automation Account will create an "Azure Run As" account that will be used in the runbook to authenticate and run the AzureRm* scripts below.

Deallocate-StoppedVMs.ps1
> An example script which gets all the ARM resources using the Run As Account (Service Principal). Then for each resource group, get all of the VMs and get the status. If the Status is Stopped...billing is still occurring, so this script will deallocate these.


 
## Conclusion ##

This section will briefly summarize the technical story with the following details included:

- Measurable impact/benefits resulting from the implementation of the solution.

- General lessons:

  - Insights the team came away with.

  - What can be applied or reused for other environments or customers.

- Opportunities going forward:

  - Details on how the customer plans to proceed or what more they hope to accomplish.

*If you’d really like to make your write-up pop, include a customer quote highlighting impact, benefits, general lessons, and/or opportunities. Attribute all quotes with Name, Title, Company.*

## Source code ##
This section should include links to the GitHub repo/s that include all of the source code for the project. 


## Additional resources ##
In this section, include a list of links to resources that complement your story, including (but not limited to) the following:

- Documentation

- Blog posts

- GitHub repos

- Etc…